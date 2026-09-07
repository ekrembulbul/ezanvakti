package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

/** AlarmManager ile tek seferlik alarm planlama/iptal. Planlanan id'ler, toplu
 *  iptal edilebilsin diye SharedPreferences'ta tutulur. */
object AlarmScheduling {
    private const val PREFS = "ezanvakti_alarms"
    private const val KEY_IDS = "scheduled_ids"
    const val ACTION_FIRE = "com.ekrembulbul.ezanvakti.ALARM_FIRE"

    fun schedule(context: Context, args: AlarmArgs) {
        require(args.isValid) { "Invalid alarm arguments" }
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = firePendingIntent(context, args, create = true)!!
        // setAlarmClock: kullanici-gorunur alarm; Doze'da bile tetiklenir.
        am.setAlarmClock(AlarmManager.AlarmClockInfo(args.timeMillis, pi), pi)
        val updated = ids(context).toMutableSet().apply { add(args.id) }
        if (!prefs(context).edit().putStringSet(KEY_IDS, updated)
                .putString(argsKey(args.id), args.toJson()).commit()) {
            am.cancel(pi)
            throw IllegalStateException("Alarm persistence failed")
        }
    }

    fun cancel(context: Context, id: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Also retire PendingIntents from releases that only used hashCode.
        for (legacy in listOf(false, true)) {
            val pi = firePendingIntentForId(context, id, legacy)
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
        removeId(context, id)
    }

    fun cancelAll(context: Context) {
        val active = AndroidMissionStore.missions(context).activeOccurrences(System.currentTimeMillis())
        for (id in ids(context).toList()) {
            val args = argsForId(context, id)
            val occurrence = args?.let { it.alarmId + "#at" + it.originalFireAtMillis }
            if (args?.isWatchdog == true && occurrence in active) continue
            cancel(context, id)
        }
    }

    fun cancelAlarm(context: Context, alarmId: String) {
        for (id in ids(context).toList()) {
            if (id == alarmId || argsForId(context, id)?.alarmId == alarmId || id.startsWith(alarmId + "#")) {
                cancel(context, id)
            }
        }
        AndroidMissionStore.missions(context).removeAlarm(alarmId)
    }

    fun cancelChain(context: Context, occurrenceId: String) {
        ids(context).toList().filter { it.startsWith(occurrenceId + "#") }.forEach { cancel(context, it) }
    }

    fun rearm(context: Context, session: NativeMissionSession, at: Long) {
        cancelChain(context, session.occurrenceId)
        schedule(context, session.watchdog(at))
    }

    fun intentData(id: String, kind: String = "fire"): Uri = Uri.Builder()
        .scheme("ezanvakti-alarm").authority(kind).appendPath(id).build()

    private fun firePendingIntent(
        context: Context,
        args: AlarmArgs,
        create: Boolean,
    ): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            data = intentData(args.id)
            args.writeTo(this)
        }
        val flags = (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE) or
            PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, args.id.hashCode(), intent, flags)
    }

    private fun firePendingIntentForId(
        context: Context,
        id: String,
        legacy: Boolean,
    ): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            if (!legacy) data = intentData(id)
        }
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, flags)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun ids(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_IDS, emptySet()) ?: emptySet()

    fun removeId(context: Context, id: String) {
        val set = ids(context).toMutableSet().apply { remove(id) }
        prefs(context).edit().remove(argsKey(id)).putStringSet(KEY_IDS, set).apply()
    }

    private fun argsKey(id: String) = "args_$id"

    fun argsForId(context: Context, id: String): AlarmArgs? =
        prefs(context).getString(argsKey(id), null)?.let { AlarmArgs.fromJson(it) }

    /** Saklanan tüm alarm args'larını döner (reboot sonrası yeniden kurmak için). */
    fun allArgs(context: Context): List<AlarmArgs> =
        ids(context).mapNotNull { id ->
            prefs(context).getString(argsKey(id), null)?.let { AlarmArgs.fromJson(it) }
        }
}
