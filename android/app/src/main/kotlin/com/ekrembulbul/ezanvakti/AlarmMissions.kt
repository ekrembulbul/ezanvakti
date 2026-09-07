package com.ekrembulbul.ezanvakti

import org.json.JSONArray
import org.json.JSONObject

data class MissionEvent(
    val alarmId: String,
    val firedAt: Long,
    val stoppedAt: Long,
    val snoozeUsed: Int,
    val rearmCount: Int,
    val chainStopped: Boolean = false,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "alarmId" to alarmId, "firedAt" to firedAt, "stoppedAt" to stoppedAt,
        "snoozeUsed" to snoozeUsed, "rearmCount" to rearmCount, "chainStopped" to chainStopped,
    )
}

data class NativeMissionSession(
    val args: AlarmArgs,
    val firedAtMillis: Long,
    val receivedAtMillis: Long,
    val stoppedAtMillis: Long,
    val pending: Boolean = true,
    val snoozeUsed: Int = 0,
    val rearmCount: Int = 0,
    val deadlineMillis: Long? = null,
    val snoozedUntilMillis: Long? = null,
    val begun: Boolean = false,
    val ringingScheduleId: String? = null,
) {
    val occurrenceId get() = args.alarmId + "#at" + firedAtMillis
    val chainDeadline get() = firedAtMillis + args.chainDurationMillis
    fun canContinue(now: Long) = pending && (!args.missionEnabled ||
        (now < chainDeadline && rearmCount <= args.maxRearms))

    fun watchdog(at: Long) = args.copy(
        id = occurrenceId + "#w", timeMillis = at, originalFireAtMillis = firedAtMillis,
        repeatWeekdays = emptyList(),
    )

    fun toJson(): JSONObject = JSONObject().apply {
        put("args", JSONObject(args.toJson()))
        put("firedAt", firedAtMillis)
        put("receivedAt", receivedAtMillis)
        put("stoppedAt", stoppedAtMillis)
        put("pending", pending)
        put("snoozeUsed", snoozeUsed)
        put("rearmCount", rearmCount)
        put("deadline", deadlineMillis ?: JSONObject.NULL)
        put("snoozedUntil", snoozedUntilMillis ?: JSONObject.NULL)
        put("begun", begun)
        put("ringingId", ringingScheduleId ?: JSONObject.NULL)
    }

    companion object {
        fun fromJson(value: JSONObject): NativeMissionSession {
            val args = requireNotNull(AlarmArgs.fromJson(value.getJSONObject("args").toString()))
            return NativeMissionSession(
                args, value.getLong("firedAt"), value.getLong("receivedAt"), value.getLong("stoppedAt"),
                value.getBoolean("pending"), value.getInt("snoozeUsed"), value.getInt("rearmCount"),
                if (value.isNull("deadline")) null else value.getLong("deadline"),
                if (value.isNull("snoozedUntil")) null else value.getLong("snoozedUntil"),
                value.getBoolean("begun"),
                if (value.isNull("ringingId")) null else value.getString("ringingId"),
            )
        }
    }
}

data class MissionState(
    val sessions: MutableMap<String, NativeMissionSession> = linkedMapOf(),
    val events: MutableList<MissionEvent> = mutableListOf(),
) {
    fun toJson(): String = JSONObject().apply {
        put("sessions", JSONObject().apply {
            sessions.forEach { (id, session) -> put(id, session.toJson()) }
        })
        put("events", JSONArray(events.map { JSONObject(it.toMap()) }))
    }.toString()

    companion object {
        fun fromJson(json: String): MissionState {
            val value = JSONObject(json)
            val state = MissionState()
            val sessions = value.getJSONObject("sessions")
            sessions.keys().forEach { id -> state.sessions[id] = NativeMissionSession.fromJson(sessions.getJSONObject(id)) }
            val events = value.getJSONArray("events")
            for (i in 0 until events.length()) {
                val event = events.getJSONObject(i)
                state.events.add(MissionEvent(
                    event.getString("alarmId"), event.getLong("firedAt"), event.getLong("stoppedAt"),
                    event.getInt("snoozeUsed"), event.getInt("rearmCount"), event.optBoolean("chainStopped", false),
                ))
            }
            return state
        }
    }
}

interface MissionStateStorage {
    fun read(): MissionState
    fun write(state: MissionState)
}

data class MissionStopped(val session: NativeMissionSession, val event: MissionEvent, val rearmAtMillis: Long?)

/** Pure mission transitions. Android persistence and alarm delivery are adapters. */
class AlarmMissions(private val storage: MissionStateStorage) {
    companion object { private val lock = Any() }

    private fun <T> mutate(operation: (MissionState) -> T): T = synchronized(lock) {
        val state = storage.read()
        val result = operation(state)
        storage.write(state)
        result
    }

    fun session(id: String): NativeMissionSession? = synchronized(lock) { storage.read().sessions[id] }

    fun fired(args: AlarmArgs, receivedAt: Long): Boolean = mutate { state ->
        if (!args.isValid || args.timeMillis > receivedAt) return@mutate false
        val fire = args.originalFireAtMillis ?: args.timeMillis
        val current = state.sessions[args.alarmId]
        if (args.isWatchdog && (current == null || !current.canContinue(receivedAt) || current.firedAtMillis != fire)) {
            return@mutate false
        }
        if (args.isWatchdog && args.timeMillis != (current?.snoozedUntilMillis ?: current?.deadlineMillis)) return@mutate false
        if (current?.firedAtMillis == fire && !current.pending) return@mutate false
        val session = if (current?.firedAtMillis == fire) current else NativeMissionSession(
            args, fire, receivedAt, receivedAt,
        )
        state.sessions[args.alarmId] = session.copy(ringingScheduleId = args.id)
        true
    }

    fun stop(args: AlarmArgs, now: Long): MissionStopped? = mutate { state ->
        val current = state.sessions[args.alarmId] ?: return@mutate null
        if (!current.pending || current.ringingScheduleId != args.id ||
            current.firedAtMillis != (args.originalFireAtMillis ?: args.timeMillis)) return@mutate null
        val ended = current.args.missionEnabled &&
            (now >= current.chainDeadline || current.rearmCount >= current.args.maxRearms)
        val next = if (current.args.missionEnabled && !ended)
            minOf(now + current.args.graceSeconds * 1000L, current.chainDeadline) else null
        val session = current.copy(
            stoppedAtMillis = now, pending = !ended && current.args.opensApp,
            rearmCount = current.rearmCount + if (next == null) 0 else 1,
            deadlineMillis = next, snoozedUntilMillis = null, begun = false, ringingScheduleId = null,
        )
        val event = MissionEvent(args.alarmId, current.firedAtMillis, now, session.snoozeUsed, session.rearmCount, ended)
        state.sessions[args.alarmId] = session
        if (args.opensApp) state.events.add(event)
        MissionStopped(session, event, next)
    }

    fun consume(alarmId: String? = null): List<MissionEvent> = mutate { state ->
        val selected = alarmId ?: state.events.firstOrNull()?.alarmId ?: return@mutate emptyList()
        val events = state.events.filter { it.alarmId == selected }
        state.events.removeAll { it.alarmId == selected }
        events
    }

    fun begin(alarmId: String, now: Long): NativeMissionSession? = mutate { state ->
        val current = state.sessions[alarmId] ?: return@mutate null
        if (!current.args.missionEnabled || !current.canContinue(now) || (current.snoozedUntilMillis ?: 0) > now) return@mutate null
        if (current.begun) return@mutate current
        val session = current.copy(begun = true,
            deadlineMillis = minOf(now + current.args.missionTimeoutSeconds * 1000L, current.chainDeadline))
        state.sessions[alarmId] = session
        session
    }

    fun snooze(alarmId: String, minutes: Int, now: Long): NativeMissionSession? = mutate { state ->
        val current = state.sessions[alarmId] ?: return@mutate null
        val limit = current.args.maxSnoozes ?: if (current.args.missionEnabled) 5 else Int.MAX_VALUE
        val next = now + minutes * 60_000L
        if (!current.canContinue(now) || !current.args.snoozeEnabled ||
            minutes != current.args.snoozeMinutes || minutes <= 0 || current.snoozeUsed >= limit ||
            (current.snoozedUntilMillis ?: 0) > now || (current.args.missionEnabled && next >= current.chainDeadline)) return@mutate null
        val session = current.copy(snoozeUsed = current.snoozeUsed + 1, snoozedUntilMillis = next,
            deadlineMillis = null, begun = false, ringingScheduleId = null)
        state.sessions[alarmId] = session
        session
    }

    fun finish(alarmId: String): String? = mutate { state ->
        val current = state.sessions[alarmId]
        if (current != null) state.sessions[alarmId] = current.copy(
            pending = false, deadlineMillis = null, snoozedUntilMillis = null, ringingScheduleId = null)
        state.events.removeAll { it.alarmId == alarmId }
        current?.occurrenceId
    }

    fun restore(session: NativeMissionSession) = mutate { state ->
        state.sessions[session.args.alarmId] = session
    }

    fun removeAlarm(alarmId: String) = mutate { state ->
        state.sessions.remove(alarmId)
        state.events.removeAll { it.alarmId == alarmId }
    }

    fun activeOccurrences(now: Long): Set<String> = synchronized(lock) {
        storage.read().sessions.values.filter {
            it.canContinue(now) && (it.args.missionEnabled || it.ringingScheduleId != null ||
                (it.snoozedUntilMillis ?: 0) > now || it.stoppedAtMillis + 45_000 > now)
        }.map { it.occurrenceId }.toSet()
    }

    fun ringing(): AlarmArgs? = synchronized(lock) {
        storage.read().sessions.values.lastOrNull { it.pending && it.ringingScheduleId != null }?.let {
            if (it.ringingScheduleId == it.args.id) it.args
            else it.watchdog(it.deadlineMillis ?: it.snoozedUntilMillis ?: it.firedAtMillis)
        }
    }
}
