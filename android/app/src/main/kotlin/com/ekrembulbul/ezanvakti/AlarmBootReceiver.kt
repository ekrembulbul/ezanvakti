package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.TimeZone

/** Saklanan alarmları uygulama açılmadan yeniden kurar:
 *  - Cihaz yeniden başladığında ya da uygulama güncellendiğinde: AlarmManager
 *    kayıtları silindiği için hepsi yeniden kurulur. Geçmiş tek seferlik
 *    kayıtlar atlanır; haftalık tekrarlar ileri alınır ve süresi dolmamış
 *    görev nöbetçileri korunur.
 *  - Kesin alarm izni yeniden verildiğinde: izin kapatılınca Android bütün
 *    kesin alarmları siler; açılıştaki gibi kurulur.
 *  - Saat elle değiştiğinde: OS kayıtları durur, yalnız sıradaki anlar tazelenir.
 *  - Saat dilimi değiştiğinde: sabit saatli alarmlar yeni dilimde aynı duvar
 *    saatine kaydırılır (bkz. [AlarmTimeShift]).
 *  Her durumda sessiz pencere planı da yeniden uygulanır. */
class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            -> {
                rescheduleFutureAlarms(context, recoverMissions = true)
                AlarmScheduling.rememberZone(context)
            }
            Intent.ACTION_TIME_CHANGED -> rescheduleFutureAlarms(context, recoverMissions = false)
            Intent.ACTION_TIMEZONE_CHANGED -> shiftForTimeZone(context, intent)
            else -> return
        }
        QuietModeController.reapply(context)
        // Widget ve sabit satır: saat, dilim ya da açılış değişince yeniden
        // çizilir ve sonraki sınır yeniden kurulur.
        try {
            com.ekrembulbul.ezanvakti.widget.SurfaceRefresher.refreshAll(context)
        } catch (error: Exception) {
            android.util.Log.e("EzanWidget", "event=surface_refresh_failed type=" + error.javaClass.simpleName)
        }
    }

    private fun shiftForTimeZone(context: Context, intent: Intent) {
        val to = intent.getStringExtra("time-zone")?.let { TimeZone.getTimeZone(it) } ?: TimeZone.getDefault()
        val from = AlarmScheduling.rememberedZone(context)
        AlarmScheduling.rememberZone(context, to)
        if (from == null || from.id == to.id) return
        val now = System.currentTimeMillis()
        for (args in AlarmScheduling.allArgs(context)) {
            try {
                val shifted = AlarmTimeShift.shift(args, from, to, now)
                when {
                    shifted == null -> AlarmScheduling.cancel(context, args.id)
                    shifted != args -> AlarmScheduling.schedule(context, shifted)
                }
            } catch (error: Exception) {
                AlarmJournal(context).record("timezone_shift", args, result = "failed", error = error)
            }
        }
    }

    /** [recoverMissions]: OS kayıtları silindiyse (açılış, izin) görev
     *  nöbetçileri de kurtarılır. Saat değişiminde nöbetçiler OS'ta durduğu
     *  için kurtarma yeni kimlikle ikinci bir zamanlayıcı kurardı. */
    private fun rescheduleFutureAlarms(context: Context, recoverMissions: Boolean) {
        val now = System.currentTimeMillis()
        val missions = AndroidMissionStore.missions(context)
        for (args in AlarmScheduling.allArgs(context)) {
            try {
                if (!missions.isEnabled(args.alarmId)) {
                    AlarmScheduling.cancel(context, args.id)
                    continue
                }
                // Restore one authoritative timer per session below. Old
                // watchdog records may refer to an expired snooze or deadline.
                if (args.isWatchdog) continue
                val next = when {
                    args.timeMillis > now -> args
                    else -> AlarmRepeats.next(args, now)
                }
                if (next != null) AlarmScheduling.schedule(context, next)
            } catch (error: Exception) {
                AlarmJournal(context).record("boot_rearm", args, result = "failed", error = error)
            }
        }
        if (!recoverMissions) return
        for (previous in missions.pendingSessions()) {
            try {
                val recovered = previous.recovery(now) ?: continue
                val deadline = recovered.snoozedUntilMillis ?: recovered.deadlineMillis ?: continue
                // Reboot removes OS alarms even when their persisted arguments
                // remain. Force an SDK call instead of reusing that stale cache.
                missions.restore(recovered.copy(timerScheduleId = null))
                AlarmScheduling.rearm(context, recovered.copy(timerScheduleId = null), deadline)
            } catch (error: Exception) {
                if (missions.session(previous.args.alarmId)?.timerScheduleId == null) {
                    missions.restore(previous)
                }
                AlarmJournal(context).record("boot_mission_recovery", previous.args, result = "failed", error = error)
            }
        }
    }
}
