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
                        AndroidMissionStore.missions(context).enableAlarm(args.alarmId,
                            AlarmScheduling.allArgs(context).map { it.alarmId }.toSet())
                        AlarmScheduling.schedule(context, args)
                        result.success(null)
                    }
                    "reconcileAlarms" -> {
                        val values = call.arguments as Map<*, *>
                        require((values["protocolVersion"] as? Number)?.toInt() == 2)
                        val records = (values["records"] as List<*>).map { AlarmArgs.fromMap(it as Map<*, *>) }
                        val enabled = (values["enabledAlarmIds"] as List<*>).map { it as String }.toSet()
                        val preserved = (values["preserveAlarmIds"] as List<*>).map { it as String }.toSet()
                        require(enabled.all { it.isNotBlank() && it.length <= 256 })
                        val periods = (values["preservedPeriods"] as? List<*> ?: emptyList<Any>()).map {
                            val item = it as Map<*, *>
                            val root = item["alarmId"] as String
                            val from = (item["fromMillis"] as Number).toLong()
                            val until = (item["untilMillis"] as Number).toLong()
                            require(root in enabled && from > 0 && until > from && until <= 8_640_000_000_000_000L)
                            AlarmPreservedPeriod(root, from, until)
                        }
                        val skips = (values["skippedOccurrences"] as? List<*> ?: emptyList<Any>()).map {
                            val item = it as Map<*, *>
                            val root = item["alarmId"] as String
                            val fire = (item["fireAtMillis"] as Number).toLong()
                            require(root in enabled && fire > 0)
                            AlarmSuppression(root, fire)
                        }
                        // Android records a mission at native delivery, before
                        // opening Flutter; iOS-only preplanned ladders are not added.
                        result.success(AlarmScheduling.reconcile(context, records, enabled, preserved, skips, periods))
                    }
                    "cancelAlarm" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        try { AlarmScheduling.cancelAlarm(context, id) }
                        finally { AlarmRingService.cancelForAlarm(context, id) }
                        result.success(null)
                    }
                    "cancelAllAlarms" -> {
                        AlarmScheduling.cancelAll(context)
                        result.success(null)
                    }
                    "consumeMissionEvents" -> result.success(
                        AndroidMissionStore.missions(context).consume(call.argument<String>("alarmId")).map { it.toMap() },
                    )
                    "getMissionSessions" -> result.success(
                        AndroidMissionStore.missions(context).pendingSessions().map { it.snapshot() },
                    )
                    "beginMission", "snoozeMission" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        val missions = AndroidMissionStore.missions(context)
                        val previous = missions.session(id)
                        val expected = call.argument<Number>("firedAtMillis")?.toLong()
                        require(expected == null || previous?.firedAtMillis == expected) { "Stale occurrence" }
                        val now = System.currentTimeMillis()
                        val session = if (call.method == "beginMission") missions.begin(id, now)
                            else missions.snooze(id, call.argument<Number>("minutes")?.toInt() ?: 0, now)
                        requireNotNull(session) { "Mission action is unavailable" }
                        try {
                            val deadline = if (call.method == "beginMission") session.deadlineMillis else session.snoozedUntilMillis
                            AlarmScheduling.rearm(context, session, requireNotNull(deadline))
                            AlarmRingService.cancelForAlarm(context, id, session.firedAtMillis)
                            AlarmJournal(context).record(call.method, session.args)
                        } catch (error: Exception) {
                            if (previous != null && missions.session(id)?.timerScheduleId == previous.timerScheduleId) {
                                missions.restore(previous)
                            }
                            throw error
                        }
                        result.success(null)
                    }
                    "completeMission", "abortMission" -> {
                        val id = requireNotNull(call.argument<String>("id"))
                        val missions = AndroidMissionStore.missions(context)
                        val session = missions.session(id)
                        val expected = call.argument<Number>("firedAtMillis")?.toLong()
                        require(expected == null || session == null || session.firedAtMillis == expected) { "Stale occurrence" }
                        missions.finish(id)
                        try {
                            session?.let { AlarmScheduling.cancelChain(context, it.occurrenceId) }
                        } finally {
                            AlarmRingService.cancelForAlarm(context, id, expected ?: session?.firedAtMillis)
                        }
                        AlarmJournal(context).record(call.method, session?.args, id)
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
                AlarmJournal(context).record(call.method, result = "failed", error = error)
                result.error("alarm_operation_failed", "Alarm operation failed",
                    mapOf("operation" to call.method, "nativeCode" to error.javaClass.name))
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
