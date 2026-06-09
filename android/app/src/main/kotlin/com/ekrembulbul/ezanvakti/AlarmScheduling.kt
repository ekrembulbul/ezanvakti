package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/** AlarmManager ile tek seferlik alarm planlama/iptal. Planlanan id'ler, toplu
 *  iptal edilebilsin diye SharedPreferences'ta tutulur. */
object AlarmScheduling {
    private const val PREFS = "ezanvakti_alarms"
    private const val KEY_IDS = "scheduled_ids"
    const val ACTION_FIRE = "com.ekrembulbul.ezanvakti.ALARM_FIRE"

    fun schedule(context: Context, args: AlarmArgs) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePendingIntent(context, args, create = true)!!
        // setAlarmClock: kullanici-gorunur alarm; Doze'da bile tetiklenir.
        am.setAlarmClock(AlarmManager.AlarmClockInfo(args.timeMillis, pi), pi)
        addId(context, args.id)
    }

    fun cancel(context: Context, id: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePendingIntentForId(context, id, create = false)
        if (pi != null) {
            am.cancel(pi)
            pi.cancel()
        }
        removeId(context, id)
    }

    fun cancelAll(context: Context) {
        ids(context).toList().forEach { cancel(context, it) }
    }

    private fun firePendingIntent(
        context: Context,
        args: AlarmArgs,
        create: Boolean,
    ): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            args.writeTo(this)
        }
        val flags = (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE) or
            PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, args.id.hashCode(), intent, flags)
    }

    private fun firePendingIntentForId(
        context: Context,
        id: String,
        create: Boolean,
    ): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java).apply { action = ACTION_FIRE }
        val flags = (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE) or
            PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, flags)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun ids(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_IDS, emptySet()) ?: emptySet()

    private fun addId(context: Context, id: String) {
        val set = ids(context).toMutableSet().apply { add(id) }
        prefs(context).edit().putStringSet(KEY_IDS, set).apply()
    }

    fun removeId(context: Context, id: String) {
        val set = ids(context).toMutableSet().apply { remove(id) }
        prefs(context).edit().putStringSet(KEY_IDS, set).apply()
    }
}
