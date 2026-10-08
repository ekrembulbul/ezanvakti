package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter <-> cihaz ayarları köprüsü: tam ekran alarm izni, pil
 *  optimizasyonu, Rahatsız Etme erişimi ve sessiz pencere planı. */
class DeviceChannel(private val activity: Activity) {
    companion object { const val CHANNEL = "com.ekrembulbul.ezanvakti/device" }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                            activity.getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() ?: true
                        else true,
                    )
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            open(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, withPackage = true)
                        }
                        result.success(null)
                    }
                    "batteryStatus" -> {
                        val power = activity.getSystemService(PowerManager::class.java)
                        result.success(mapOf(
                            "manufacturer" to Build.MANUFACTURER.lowercase(),
                            "brand" to Build.BRAND.lowercase(),
                            "ignoringOptimizations" to (power?.isIgnoringBatteryOptimizations(activity.packageName) ?: true),
                        ))
                    }
                    "openBatteryOptimizationSettings" -> {
                        // Liste ekranı: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni
                        // Play politikasında kısıtlı, bu ekran izin istemez.
                        open(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        result.success(null)
                    }
                    "isQuietModeSupported" -> result.success(QuietModeController.isSupported())
                    "hasQuietModeAccess" -> result.success(QuietModeController.hasAccess(activity))
                    "openQuietModeAccessSettings" -> {
                        open(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        result.success(null)
                    }
                    "setQuietSchedule" -> {
                        val raw = call.argument<List<*>>("intervals") ?: emptyList<Any>()
                        QuietModeController.setSchedule(activity, QuietSchedule.parse(raw))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                Log.e("EzanDevice", "event=device_call_failed method=" + call.method + " type=" + error.javaClass.simpleName)
                result.error("device_operation_failed", "Device operation failed", mapOf("operation" to call.method))
            }
        }
    }

    /** Ayar ekranı bulunamazsa uygulama ayrıntıları açılır. */
    private fun open(action: String, withPackage: Boolean = false) {
        val packageUri = Uri.fromParts("package", activity.packageName, null)
        try {
            activity.startActivity(Intent(action).apply { if (withPackage) data = packageUri })
        } catch (_: ActivityNotFoundException) {
            activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))
        }
    }
}
