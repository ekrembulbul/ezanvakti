package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var alarmChannel: AlarmChannel? = null
    private val channelName = "com.ekrembulbul.ezanvakti/exact_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sesli/kalıcı alarm köprüsü.
        alarmChannel = AlarmChannel(this).also { it.register(flutterEngine) }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isExactAlarmAllowed" -> {
                        result.success(isExactAlarmAllowed())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        alarmChannel?.dispose()
        alarmChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isExactAlarmAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        return alarmManager?.canScheduleExactAlarms() ?: false
    }
}
