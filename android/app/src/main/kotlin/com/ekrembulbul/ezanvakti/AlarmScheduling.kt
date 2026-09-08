package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.util.UUID

/** AlarmManager ile tek seferlik alarm planlama/iptal. Planlanan id'ler, toplu
 *  iptal edilebilsin diye SharedPreferences'ta tutulur. */
object AlarmScheduling {
    private const val PREFS = "ezanvakti_alarms"
    private const val KEY_IDS = "scheduled_ids"
    const val ACTION_FIRE = "com.ekrembulbul.ezanvakti.ALARM_FIRE"

    fun schedule(context: Context, args: AlarmArgs) {
        require(args.isValid) { "Invalid alarm arguments" }
        check(AndroidMissionStore.missions(context).isEnabled(args.alarmId)) { "Alarm is disabled" }
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val previous = argsForId(context, args.id)
        val previousIds = ids(context)
        val pi = firePendingIntent(context, args, create = true)!!
        var accepted = false
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(args.timeMillis, pi), pi)
            accepted = true
            val updated = previousIds.toMutableSet().apply { add(args.id) }
            check(prefs(context).edit().putStringSet(KEY_IDS, updated)
                .putString(argsKey(args.id), args.toJson()).commit()) {
                "Alarm persistence failed"
            }
            AlarmJournal(context).record("scheduled", args)
        } catch (error: Exception) {
            // FLAG_UPDATE_CURRENT also changes an old PendingIntent's extras.
            // Restore them even if the SDK rejected the replacement.
            try {
                if (previous != null) {
                    val restored = firePendingIntent(context, previous, create = true)!!
                    if (accepted) {
                        if (previous.timeMillis > System.currentTimeMillis()) {
                            am.setAlarmClock(AlarmManager.AlarmClockInfo(previous.timeMillis, restored), restored)
                        } else am.cancel(restored)
                    }
                    check(prefs(context).edit().putStringSet(KEY_IDS, previousIds)
                        .putString(argsKey(args.id), previous.toJson()).commit())
                } else {
                    am.cancel(pi)
                    pi.cancel()
                    removeId(context, args.id)
                }
            } catch (rollbackError: Exception) {
                AlarmJournal(context).record("schedule_rollback", previous, args.id, "failed", rollbackError)
            }
            AlarmJournal(context).record("schedule", args, result = "failed", error = error)
            throw error
        }
    }

    fun cancel(context: Context, id: String) {
        val previous = argsForId(context, id)
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
        AlarmJournal(context).record("cancelled", previous, id)
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
        val missions = AndroidMissionStore.missions(context)
        missions.disableAlarm(alarmId, allArgs(context).map { it.alarmId }.toSet())
        var failure: Exception? = null
        for (id in ids(context).toList()) {
            if (id == alarmId || argsForId(context, id)?.alarmId == alarmId || id.startsWith(alarmId + "#")) {
                try { cancel(context, id) }
                catch (error: Exception) { failure = failure ?: error }
            }
        }
        if (failure != null) throw failure
        missions.removeAlarm(alarmId)
    }

    fun cancelChain(context: Context, occurrenceId: String, exceptId: String? = null) {
        var failure: Exception? = null
        ids(context).toList().filter { it.startsWith(occurrenceId + "#") && it != exceptId }.forEach {
            try { cancel(context, it) }
            catch (error: Exception) { failure = failure ?: error }
        }
        if (failure != null) throw failure
    }

    fun rearm(context: Context, session: NativeMissionSession, at: Long) {
        require(at > System.currentTimeMillis()) { "Mission deadline is in the past" }
        val existing = session.timerScheduleId?.let { argsForId(context, it) }
        val next = if (existing?.timeMillis == at) existing else {
            session.watchdog(at, session.occurrenceId + "#w" + UUID.randomUUID()).also {
                schedule(context, it)
                AndroidMissionStore.missions(context).restore(session.copy(timerScheduleId = it.id))
            }
        }
        cancelChain(context, session.occurrenceId, exceptId = next.id)
    }

    fun reconcile(context: Context, records: List<AlarmArgs>, enabled: Set<String>,
        preserved: Set<String>, skips: List<AlarmSuppression>,
        periods: List<AlarmPreservedPeriod> = emptyList()): Map<String, String> {
        val missions = AndroidMissionStore.missions(context)
        val previous = missions.pendingSessions()
        val platform = object : AlarmSchedulePlatform {
            override fun records() = allArgs(context).associateBy { it.id }
            override fun ids() = AlarmScheduling.ids(context)
            override fun schedule(args: AlarmArgs) = AlarmScheduling.schedule(context, args)
            override fun cancel(id: String) = AlarmScheduling.cancel(context, id)
        }
        val failures = AlarmReconciler(platform, missions).reconcile(records, enabled, preserved,
            System.currentTimeMillis(), skips, periods)
        for (session in previous) {
            if (session.args.alarmId !in enabled) AlarmRingService.cancelForAlarm(context, session.args.alarmId)
            else if (skips.any { it.occurrenceId == session.occurrenceId }) {
                AlarmRingService.cancelForAlarm(context, session.args.alarmId, session.firedAtMillis)
            }
        }
        AlarmJournal(context).record("reconcile", result = if (failures.isEmpty()) "ok" else "partial")
        return failures
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
        check(prefs(context).edit().remove(argsKey(id)).putStringSet(KEY_IDS, set).commit()) {
            "Alarm cancellation could not be persisted"
        }
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
