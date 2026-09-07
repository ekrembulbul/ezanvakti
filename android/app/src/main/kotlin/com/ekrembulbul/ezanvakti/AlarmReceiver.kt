package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Alarm zamanı geldiğinde AlarmManager bunu tetikler; çalma servisini başlatır. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val args = AlarmArgs.readFrom(intent)
        val receivedAt = System.currentTimeMillis()
        val stored = AlarmScheduling.argsForId(context, args.id)
        if (!args.isValid || stored == null || stored.timeMillis != args.timeMillis || args.timeMillis > receivedAt) {
            Log.w("EzanAlarm", "event=stale_delivery_ignored id=" + args.id)
            return
        }
        Log.i("EzanAlarm", "event=received id=" + args.id + " expected_ms=" + args.timeMillis +
            " received_ms=" + receivedAt + " lateness_ms=" + (receivedAt - args.timeMillis))
        // Tek seferlik tetiklendi; planlanan id listesinden çıkar (tekrar planlama
        // Flutter tarafında / snooze ile yapılır).
        AlarmScheduling.removeId(context, args.id)
        try {
            AlarmRepeats.next(args, receivedAt)?.let { AlarmScheduling.schedule(context, it) }
        } catch (error: Exception) {
            Log.e("EzanAlarm", "event=repeat_failed id=" + args.alarmId + " type=" + error.javaClass.simpleName)
        }

        val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_START
            args.writeTo(this)
            putExtra("receivedAtMillis", receivedAt)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
