package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Cihaz yeniden başladığında (veya uygulama güncellendiğinde) saklanan
 *  alarmları yeniden kurar. AlarmManager kayıtları reboot'ta silindiği için
 *  gereklidir. Geçmiş zamanlı (cihaz kapalıyken kaçan) alarmlar atlanır;
 *  uygulama bir sonraki açılışta zaten taze yeniden planlar. */
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
            if (args.timeMillis > now) {
                AlarmScheduling.schedule(context, args)
            }
        }
    }
}
