package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Cihaz yeniden başladığında (veya uygulama güncellendiğinde) saklanan
 *  alarmları yeniden kurar. AlarmManager kayıtları reboot'ta silindiği için
 *  gereklidir. Geçmiş tek seferlik kayıtlar atlanır; haftalık tekrarlar ileri
 *  alınır ve süresi dolmamış görev nöbetçileri korunur. */
class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> rescheduleFutureAlarms(context)
        }
    }

    private fun rescheduleFutureAlarms(context: Context) {
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
