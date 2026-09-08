package com.ekrembulbul.ezanvakti

import java.util.Calendar

data class AlarmPreservedPeriod(val alarmId: String, val fromMillis: Long, val untilMillis: Long) {
    fun matches(args: AlarmArgs, now: Long): Boolean {
        val fire = args.originalFireAtMillis ?: args.timeMillis
        return args.alarmId == alarmId && args.repeatWeekdays.isEmpty() &&
            fire > now && fire >= fromMillis && fire < untilMillis
    }
}

data class AlarmSuppression(val alarmId: String, val fireAtMillis: Long) {
    val occurrenceId get() = alarmId + "#at" + fireAtMillis
    fun matches(args: AlarmArgs): Boolean {
        if (args.alarmId != alarmId) return false
        if (args.repeatWeekdays.isEmpty()) return (args.originalFireAtMillis ?: args.timeMillis) == fireAtMillis
        val date = Calendar.getInstance().apply { timeInMillis = fireAtMillis }
        val template = Calendar.getInstance().apply { timeInMillis = args.timeMillis }
        val isoDay = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
        return isoDay in args.repeatWeekdays &&
            date.get(Calendar.HOUR_OF_DAY) == template.get(Calendar.HOUR_OF_DAY) &&
            date.get(Calendar.MINUTE) == template.get(Calendar.MINUTE)
    }
}

interface AlarmSchedulePlatform {
    fun records(): Map<String, AlarmArgs>
    fun ids(): Set<String>
    fun schedule(args: AlarmArgs)
    fun cancel(id: String)
}

/** Synchronous native operations execute on the app's main looper. */
class AlarmReconciler(
    private val platform: AlarmSchedulePlatform,
    private val missions: AlarmMissions,
) {
    fun reconcile(records: List<AlarmArgs>, enabled: Set<String>, preserved: Set<String>,
        now: Long, skips: List<AlarmSuppression> = emptyList(),
        periods: List<AlarmPreservedPeriod> = emptyList()): Map<String, String> {
        require(preserved.all { it in enabled } && records.all { it.isValid && it.alarmId in enabled })
        require(records.map { it.id }.toSet().size == records.size)
        // Android can suppress delivery in the receiver and keep one native
        // weekly template. iOS needs dated records while a skip is pending.
        val desiredRecords = records.groupBy { it.alarmId }.flatMap { (_, values) ->
            val first = values.minBy { it.timeMillis }
            val days = first.templateWeekdays
            if (!days.isNullOrEmpty()) listOf(first.copy(id = first.alarmId, repeatWeekdays = days))
            else values
        }
        missions.setEnabledAlarmIds(enabled)
        missions.setSkippedOccurrences(skips, now)
        val failures = mutableMapOf<String, String>()
        val desired = desiredRecords.map { it.id }.toSet()
        val firstByRoot = desiredRecords.groupBy { it.alarmId }.mapValues { (_, values) -> values.minOf { it.timeMillis } }
        val ordered = desiredRecords.sortedWith(compareBy<AlarmArgs>(
            { if (it.timeMillis == firstByRoot[it.alarmId]) 0 else 1 }, { it.timeMillis }, { it.id }))
        for (record in ordered) {
            try {
                val old = platform.records()[record.id]
                val ringing = missions.pendingSessions().any { it.ringingScheduleId == record.id }
                if (!ringing && (old == null || !sameSchedule(old, record))) platform.schedule(record)
            } catch (error: Exception) {
                failures[record.alarmId] = error.javaClass.simpleName
            }
        }
        for (id in platform.ids().toList()) {
            val old = platform.records()[id]
            val root = old?.alarmId ?: id.substringBefore('#')
            if (root in enabled) {
                if (id in desired) continue
                val explicitlySkipped = old != null && skips.any { it.matches(old) }
                if (!explicitlySkipped) {
                    if (root in failures || root in preserved) continue
                    if (old != null && periods.any { it.matches(old, now) }) continue
                    val active = missions.session(root)
                    if (old != null && active?.canContinue(now) == true) {
                        if (active.ringingScheduleId == id) continue
                        if (old.isWatchdog && active.firedAtMillis == old.originalFireAtMillis &&
                            (active.timerScheduleId == id || (active.timerScheduleId == null &&
                            old.timeMillis == (active.snoozedUntilMillis ?: active.deadlineMillis)))) continue
                    }
                    if (old != null && !old.isWatchdog && old.repeatWeekdays.isEmpty() &&
                        old.timeMillis <= now + 1000 && now < old.timeMillis + old.chainDurationMillis) continue
                }
            }
            try { platform.cancel(id) }
            catch (error: Exception) { failures[root] = "cancel_failed" }
        }
        return failures
    }

    private fun sameSchedule(old: AlarmArgs, new: AlarmArgs): Boolean {
        if (old.repeatWeekdays.isNotEmpty() && old.repeatWeekdays == new.repeatWeekdays) {
            fun localTime(args: AlarmArgs): Pair<Int, Int> {
                val date = Calendar.getInstance().apply { timeInMillis = args.timeMillis }
                return (args.repeatHour ?: date.get(Calendar.HOUR_OF_DAY)) to
                    (args.repeatMinute ?: date.get(Calendar.MINUTE))
            }
            if (localTime(old) != localTime(new)) return false
            return old.copy(timeMillis = 0) == new.copy(timeMillis = 0)
        }
        return old == new
    }
}
