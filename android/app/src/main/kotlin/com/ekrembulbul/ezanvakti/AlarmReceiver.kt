package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Alarm zamanı geldiğinde AlarmManager bunu tetikler; çalma servisini başlatır. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val args = AlarmArgs.readFrom(intent)
        // Tek seferlik tetiklendi; planlanan id listesinden çıkar (tekrar planlama
        // Flutter tarafında / snooze ile yapılır).
        AlarmScheduling.removeId(context, args.id)

        val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_START
            args.writeTo(this)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
