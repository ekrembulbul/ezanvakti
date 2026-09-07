package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

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
        for (args in AlarmScheduling.allArgs(context)) {
            try {
                val missions = AndroidMissionStore.missions(context)
                val next = when {
                    args.isWatchdog -> missions.session(args.alarmId)?.takeIf {
                        it.canContinue(now) && it.firedAtMillis == args.originalFireAtMillis
                    }?.let { session ->
                        (session.snoozedUntilMillis ?: session.deadlineMillis)?.let { session.watchdog(it) }
                    }
                    args.timeMillis > now -> args
                    else -> AlarmRepeats.next(args, now)
                }
                if (next != null) AlarmScheduling.schedule(context, next)
            } catch (error: Exception) {
                Log.e("EzanAlarm", "event=boot_rearm_failed id=" + args.id + " type=" + error.javaClass.simpleName)
            }
        }
        val missions = AndroidMissionStore.missions(context)
        val ringing = missions.ringing()
        if (ringing != null && missions.session(ringing.alarmId)?.canContinue(now) == true) {
            try { AlarmScheduling.schedule(context, ringing) }
            catch (error: Exception) {
                Log.e("EzanAlarm", "event=ring_recovery_failed id=" + ringing.id + " type=" + error.javaClass.simpleName)
            }
        }
    }
}
