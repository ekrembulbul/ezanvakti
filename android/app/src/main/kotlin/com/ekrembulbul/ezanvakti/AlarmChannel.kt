package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Flutter <-> native alarm köprüsü. AlarmService (Dart) bu kanalı çağırır. */
class AlarmChannel(private val context: Context) {
    private var boundChannel: MethodChannel? = null
    companion object {
        const val CHANNEL = "com.ekrembulbul.ezanvakti/alarm"
        private var activeChannel: MethodChannel? = null

        fun notifyStopped(event: MissionEvent) {
            Handler(Looper.getMainLooper()).post {
                activeChannel?.invokeMethod("missionStopped", event.toMap())
            }
        }
    }

    fun register(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        boundChannel = channel
        activeChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "isPermissionGranted" -> result.success(canScheduleExact())
                    "requestPermission" -> result.success(canScheduleExact())
                    "scheduleAlarm" -> {
                        val args = AlarmArgs.fromMap(call.arguments as Map<*, *>)
                        AlarmScheduling.schedule(context, args)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        AlarmScheduling.cancelAlarm(context, id)
                        AlarmRingService.cancelForAlarm(context, id)
                        result.success(null)
                    }
                    "cancelAllAlarms" -> {
                        AlarmScheduling.cancelAll(context)
                        result.success(null)
                    }
                    "consumeMissionEvents" -> result.success(
                        AndroidMissionStore.missions(context).consume(call.argument<String>("alarmId")).map { it.toMap() },
                    )
                    "beginMission", "snoozeMission" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        val missions = AndroidMissionStore.missions(context)
                        val previous = missions.session(id)
                        val now = System.currentTimeMillis()
                        val session = if (call.method == "beginMission") missions.begin(id, now)
                            else missions.snooze(id, call.argument<Number>("minutes")?.toInt() ?: 0, now)
                        requireNotNull(session) { "Mission action is unavailable" }
                        if (call.method != "beginMission" || previous?.begun != true) {
                            try {
                                AlarmScheduling.rearm(context, session,
                                    requireNotNull(session.snoozedUntilMillis ?: session.deadlineMillis))
                                AlarmRingService.cancelForAlarm(context, id)
                            } catch (error: Exception) {
                                if (previous != null) missions.restore(previous)
                                throw error
                            }
                        }
                        result.success(null)
                    }
                    "completeMission", "abortMission" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        val missions = AndroidMissionStore.missions(context)
                        missions.session(id)?.let { AlarmScheduling.cancelChain(context, it.occurrenceId) }
                        missions.finish(id)
                        AlarmRingService.cancelForAlarm(context, id)
                        result.success(null)
                    }
                    "importCustomSound" -> {
                        result.success(
                            importCustomSound(
                                call.argument<String>("path"),
                                call.argument<String>("name"),
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                Log.e("EzanAlarm", "event=operation_failed method=" + call.method + " type=" + error.javaClass.simpleName)
                result.error("alarm_operation_failed", "Alarm operation failed", null)
            }
        }
    }

    fun dispose() {
        boundChannel?.setMethodCallHandler(null)
        if (activeChannel === boundChannel) activeChannel = null
        boundChannel = null
    }

    /** Seçilen ses dosyasını filesDir/alarm_sounds altına kopyalar; `custom:<ad>`
     *  döner. Çalarken [AlarmRingService] bu adı dosya yoluna çözer. */
    private fun importCustomSound(path: String?, name: String?): String? {
        if (path.isNullOrBlank() || name.isNullOrBlank()) return null
        return try {
            val src = File(path)
            if (!src.exists()) return null
            val dir = File(context.filesDir, "alarm_sounds").apply { mkdirs() }
            val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
            src.copyTo(File(dir, safe), overwrite = true)
            "custom:$safe"
        } catch (_: Exception) {
            null
        }
    }

    private fun canScheduleExact(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }
}
