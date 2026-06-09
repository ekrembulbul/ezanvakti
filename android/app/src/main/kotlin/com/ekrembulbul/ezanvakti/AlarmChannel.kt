package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Flutter <-> native alarm köprüsü. AlarmService (Dart) bu kanalı çağırır. */
class AlarmChannel(private val context: Context) {
    companion object {
        const val CHANNEL = "com.ekrembulbul.ezanvakti/alarm"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "isPermissionGranted" -> result.success(canScheduleExact())
                    "requestPermission" -> result.success(canScheduleExact())
                    "scheduleAlarm" -> {
                        val args = AlarmArgs(
                            id = call.argument<String>("id") ?: "",
                            timeMillis = (call.argument<Number>("timeMillis") ?: 0L).toLong(),
                            label = call.argument<String>("label") ?: "",
                            soundId = call.argument<String>("soundId") ?: "adhan",
                            vibrate = call.argument<Boolean>("vibrate") ?: true,
                            snoozeEnabled = call.argument<Boolean>("snoozeEnabled") ?: true,
                            snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 5,
                        )
                        AlarmScheduling.schedule(context, args)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        AlarmScheduling.cancel(context, call.argument<String>("id") ?: "")
                        result.success(null)
                    }
                    "cancelAllAlarms" -> {
                        AlarmScheduling.cancelAll(context)
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
            }
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
