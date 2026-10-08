package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.notification.Condition
import android.util.Log
import androidx.annotation.ChecksSdkIntAtLeast
import androidx.annotation.RequiresApi

/** Sessiz pencerelerde telefonu Rahatsız Etme'ye alan uygulama kuralı.
 *
 *  API 35+ hedefleyen uygulama genel DND'yi değiştiremez; sisteme kendi
 *  kuralını verir, sistem kuralları birleştirir. Bu yüzden "bitince eski
 *  haline dön" ve "kullanıcının kendi DND'sine dokunma" sistemden gelir.
 *  Plan Dart'tan gelir; burada yalnız sıradaki sınıra tek alarm kurulur. */
object QuietModeController {
    private const val TAG = "EzanQuiet"
    private const val PREFS = "ezanvakti_quiet"
    private const val KEY_INTERVALS = "intervals"
    private const val KEY_RULE_ID = "rule_id"
    private const val KEY_APPLIED = "applied_active"
    private const val REQUEST_CODE = 7301
    private val CONDITION_ID: Uri = Uri.parse("condition://com.ekrembulbul.ezanvakti/quiet")

    @ChecksSdkIntAtLeast(api = Build.VERSION_CODES.Q)
    fun isSupported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    fun hasAccess(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java)?.isNotificationPolicyAccessGranted ?: false

    fun setSchedule(context: Context, intervals: List<QuietInterval>) {
        prefs(context).edit().putString(KEY_INTERVALS, QuietSchedule.encode(intervals)).apply()
        reapply(context)
    }

    /** Planı şimdiye göre uygular ve sıradaki sınırı kurar. Sınır alarmı,
     *  açılış, saat dilimi ve izin değişiminde çağrılır; tekrar çağrılması
     *  zararsızdır. API 29 altında hiçbir şey yapmaz. */
    fun reapply(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val now = System.currentTimeMillis()
        val prefs = prefs(context)
        val intervals = QuietSchedule.prune(QuietSchedule.decode(prefs.getString(KEY_INTERVALS, null)), now)
        prefs.edit().putString(KEY_INTERVALS, QuietSchedule.encode(intervals)).apply()
        val applied = prefs.getBoolean(KEY_APPLIED, false)
        try {
            if (intervals.isEmpty()) {
                removeRule(context)
                prefs.edit().putBoolean(KEY_APPLIED, false).apply()
            } else {
                val desired = QuietSchedule.isInside(intervals, now)
                val write = QuietSchedule.decide(desired, applied)
                if (write != null) {
                    setState(context, ensureRule(context), write)
                    prefs.edit().putBoolean(KEY_APPLIED, write).apply()
                }
            }
        } catch (_: SecurityException) {
            // Erişim yok ya da geri alındı: uygulanan durum değişmez, ekran
            // uyarır; erişim gelince sonraki çağrı aynı geçişi yeniden dener.
            Log.w(TAG, "event=quiet_apply_denied")
        } catch (error: Exception) {
            Log.e(TAG, "event=quiet_apply_failed type=" + error.javaClass.simpleName)
        }
        scheduleNext(context, QuietSchedule.nextBoundary(intervals, now))
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun ensureRule(context: Context): String {
        val nm = context.getSystemService(NotificationManager::class.java)
        val prefs = prefs(context)
        prefs.getString(KEY_RULE_ID, null)?.let { id ->
            if (nm.getAutomaticZenRule(id) != null) return id
        }
        // Saklanan kimlik kaybolduysa (veri silme, yazılamadan kapanma)
        // sistemdeki kendi kuralımız benimsenir; ayarlarda kopya kural birikmez.
        nm.automaticZenRules?.entries
            ?.firstOrNull { it.value?.conditionId == CONDITION_ID }
            ?.key
            ?.let { id ->
                prefs.edit().putString(KEY_RULE_ID, id).putBoolean(KEY_APPLIED, false).apply()
                return id
            }
        // Kullanıcı kuralı sistemden silmişse yeniden kurulur; yeni kural
        // kapalı başlar.
        val rule = AutomaticZenRule(
            context.getString(R.string.quiet_rule_name),
            null,
            ComponentName(context, MainActivity::class.java),
            CONDITION_ID,
            null,
            NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            true,
        )
        val id = nm.addAutomaticZenRule(rule)
        prefs.edit().putString(KEY_RULE_ID, id).putBoolean(KEY_APPLIED, false).apply()
        return id
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun setState(context: Context, ruleId: String, active: Boolean) {
        val nm = context.getSystemService(NotificationManager::class.java)
        val state = if (active) Condition.STATE_TRUE else Condition.STATE_FALSE
        nm.setAutomaticZenRuleState(ruleId, Condition(CONDITION_ID, context.getString(R.string.quiet_rule_name), state))
    }

    /** Erişim yokken `SecurityException` atabilir; `reapply` yakalar ve
     *  saklanan kimlik ile uygulanan durum korunur. */
    private fun removeRule(context: Context) {
        val prefs = prefs(context)
        val id = prefs.getString(KEY_RULE_ID, null) ?: return
        context.getSystemService(NotificationManager::class.java)?.removeAutomaticZenRule(id)
        prefs.edit().remove(KEY_RULE_ID).apply()
    }

    private fun scheduleNext(context: Context, at: Long?) {
        try {
            val am = context.getSystemService(AlarmManager::class.java) ?: return
            val pi = PendingIntent.getBroadcast(
                context, REQUEST_CODE, Intent(context, QuietModeReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (at == null) {
                am.cancel(pi)
                return
            }
            if (!canScheduleExact(am)) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                return
            }
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } catch (_: SecurityException) {
                // Kesin alarm izni kontrolle çağrı arasında geri alındı.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (error: Exception) {
            // Sınır kurulamazsa sonraki açılış ya da yayın yeniden dener;
            // alıcıyı (boot dahil) çökertmez.
            Log.e(TAG, "event=quiet_boundary_failed type=" + error.javaClass.simpleName)
        }
    }

    private fun canScheduleExact(am: AlarmManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return am.canScheduleExactAlarms()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
