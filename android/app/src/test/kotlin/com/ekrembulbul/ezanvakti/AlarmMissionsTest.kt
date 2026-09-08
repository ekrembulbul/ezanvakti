package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class AlarmMissionsTest {
    private class Memory : MissionStateStorage {
        var state = MissionState()
        override fun read() = state
        override fun write(state: MissionState) { this.state = state }
    }
    private val fire = 1_788_760_800_000L
    private val memory = Memory()
    private val missions = AlarmMissions(memory)

    private fun args(id: String, at: Long = fire) = AlarmArgs(
        id = "$id#at$at", timeMillis = at, label = id, soundId = "default",
        vibrate = true, snoozeEnabled = true, snoozeMinutes = 5,
        alarmId = id, missionEnabled = true, maxSnoozes = 2,
    )

    @Test fun stopAndQueueKeepTwoAlarmIdentitiesSeparate() {
        val a = args("is")
        val b = args("yedek")
        assertTrue(missions.fired(a, fire))
        assertTrue(missions.fired(b, fire))
        val stopped = missions.stop(a, fire + 1000)!!
        assertEquals("is", stopped.event.alarmId)
        assertEquals(fire, stopped.event.firedAt)
        assertEquals(fire + 31_000, stopped.rearmAtMillis)
        missions.stop(b, fire + 1000)
        assertEquals(listOf("is"), missions.consume("is").map { it.alarmId })
        missions.finish("is")
        assertTrue(missions.session("yedek")!!.pending)
        assertEquals(listOf("yedek"), missions.consume().map { it.alarmId })
    }

    @Test fun completedOldWatchdogCannotRestartMission() {
        val a = args("is")
        missions.fired(a, fire)
        val stopped = missions.stop(a, fire + 1000)!!
        val watchdog = stopped.session.watchdog(fire + 31_000)
        missions.finish("is")
        assertFalse(missions.fired(watchdog, fire + 31_000))
        assertNull(missions.stop(watchdog, fire + 32_000))
    }

    @Test fun snoozeRequiresMatchingSessionAndHonorsDisabledPreference() {
        val a = args("is").copy(snoozeEnabled = false)
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        assertNull(missions.snooze("other", 5, fire + 2000))
        assertNull(missions.snooze("is", 5, fire + 2000))
        assertEquals(0, missions.session("is")!!.snoozeUsed)
    }

    @Test fun nextDayResetsCountersAndOldWatchdogCannotTouchIt() {
        val a = args("is")
        missions.fired(a, fire)
        val stopped = missions.stop(a, fire + 1000)!!
        val oldWatchdog = stopped.session.watchdog(fire + 31_000)
        missions.snooze("is", 5, fire + 2000)
        val next = args("is", fire + 86_400_000)
        missions.fired(next, next.timeMillis)
        assertEquals(0, missions.session("is")!!.snoozeUsed)
        assertFalse(missions.fired(oldWatchdog, next.timeMillis + 1000))
    }

    @Test fun lastRearmCanBeginAndNextStopReachesLimit() {
        val a = args("is").copy(maxRearms = 1)
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)!!
        val begun = missions.begin("is", fire + 2000)!!
        val watchdog = begun.watchdog(begun.deadlineMillis!!)
        missions.fired(watchdog, watchdog.timeMillis)
        assertTrue(missions.stop(watchdog, watchdog.timeMillis + 1000)!!.event.chainStopped)
    }

    @Test fun persistedArgumentsKeepMissionAndSourceTime() {
        val a = args("is").copy(originalFireAtMillis = fire - 1000, repeatWeekdays = listOf(1, 5))
        val decoded = AlarmArgs.fromJson(a.toJson())!!
        assertEquals(a.alarmId, decoded.alarmId)
        assertTrue(decoded.missionEnabled)
        assertEquals(a.originalFireAtMillis, decoded.originalFireAtMillis)
        assertEquals(a.maxSnoozes, decoded.maxSnoozes)
        assertEquals(a.repeatWeekdays, decoded.repeatWeekdays)
    }

    @Test fun persistedStateRestoresPendingEventsAndSnoozeCount() {
        val a = args("is")
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        missions.snooze("is", 5, fire + 2000)
        val restored = MissionState.fromJson(memory.state.toJson())
        assertEquals(1, restored.sessions["is"]!!.snoozeUsed)
        assertEquals("is", restored.events.single().alarmId)
    }

    @Test fun staleWatchdogCannotReplaceTheNewDeadline() {
        val a = args("is")
        missions.fired(a, fire)
        val stopped = missions.stop(a, fire + 1000)!!
        val oldWatchdog = stopped.session.watchdog(fire + 31_000)
        missions.begin("is", fire + 2000)
        assertFalse(missions.fired(oldWatchdog, oldWatchdog.timeMillis))
        assertFalse(missions.fired(a.copy(timeMillis = fire + 60_000), fire + 1000))
    }

    @Test fun expiredSnoozeIsClearedBeforeBeginningMission() {
        val a = args("is")
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        missions.snooze("is", 5, fire + 2000)
        val now = fire + 1_800_000
        val begun = missions.begin("is", now)!!
        assertNull(begun.snoozedUntilMillis)
        assertTrue(begun.deadlineMillis!! > now)
    }

    @Test fun retryOfAcceptedSnoozeDoesNotConsumeAnAdditionalRight() {
        val a = args("is").copy(maxSnoozes = 1)
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        val first = missions.snooze("is", 5, fire + 2000)!!
        val retry = missions.snooze("is", 5, fire + 3000)!!
        assertEquals(first.snoozedUntilMillis, retry.snoozedUntilMillis)
        assertEquals(1, retry.snoozeUsed)
    }

    @Test fun snapshotsPreserveTwoIndependentSnoozedSessions() {
        for (id in listOf("a", "b")) {
            val a = args(id)
            missions.fired(a, fire)
            missions.stop(a, fire + 1000)
            missions.snooze(id, 5, fire + 2000)
        }
        assertEquals(2, missions.pendingSessions().size)
        assertEquals(2, missions.pendingSessions().size)
        assertTrue(missions.pendingSessions().all { it.snoozedUntilMillis == fire + 302_000 })
        missions.finish("a")
        assertEquals("b", missions.pendingSessions().single().args.alarmId)
    }

    @Test fun bootRecoveryMovesExpiredSnoozeToFutureWithoutSpendingAnotherRight() {
        val a = args("is")
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        val snoozed = missions.snooze("is", 5, fire + 2000)!!
        val now = fire + 1_800_000
        val recovered = snoozed.recovery(now)!!
        assertNull(recovered.snoozedUntilMillis)
        assertTrue(recovered.deadlineMillis!! > now)
        assertEquals(snoozed.snoozeUsed, recovered.snoozeUsed)
        missions.restore(recovered)
        val watchdog = recovered.watchdog(recovered.deadlineMillis!!)
        assertTrue(missions.fired(watchdog, watchdog.timeMillis))
    }

    @Test fun bootRecoveryKeepsFutureSnoozeAndDoesNotReviveExpiredChain() {
        val a = args("is")
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        val snoozed = missions.snooze("is", 5, fire + 2000)!!
        assertEquals(snoozed.snoozedUntilMillis, snoozed.recovery(fire + 3000)!!.snoozedUntilMillis)
        assertNull(snoozed.recovery(snoozed.chainDeadline))
    }

    @Test fun legacySessionWithoutNewFieldsIsReadable() {
        val a = args("is")
        val json = NativeMissionSession(a, fire, fire, fire).toJson()
        for (key in listOf("timerId", "lastStopId", "lastStopTime")) json.remove(key)
        val restored = NativeMissionSession.fromJson(json)
        assertNull(restored.timerScheduleId)
        assertNull(restored.lastStopScheduleId)
    }
}
