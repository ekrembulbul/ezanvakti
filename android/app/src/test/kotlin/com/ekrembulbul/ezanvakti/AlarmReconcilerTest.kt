package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class AlarmReconcilerTest {
    private class Memory : MissionStateStorage {
        var value = MissionState()
        override fun read() = value
        override fun write(state: MissionState) { value = state }
    }
    private class Platform : AlarmSchedulePlatform {
        val accepted = linkedMapOf<String, AlarmArgs>()
        val operations = mutableListOf<String>()
        val failures = mutableSetOf<String>()
        override fun records() = accepted.toMap()
        override fun ids() = accepted.keys.toSet()
        override fun schedule(args: AlarmArgs) {
            operations.add("schedule:" + args.id)
            if (args.id in failures) throw IllegalStateException("injected")
            accepted[args.id] = args
        }
        override fun cancel(id: String) {
            operations.add("cancel:" + id)
            accepted.remove(id)
        }
    }
    private val now = 1_800_000_000_000L
    private fun alarm(root: String, at: Long) = AlarmArgs(
        id = root + "#at" + at, timeMillis = at, label = root, soundId = "default",
        vibrate = true, snoozeEnabled = true, snoozeMinutes = 5, alarmId = root,
        missionEnabled = true,
    )

    @Test fun unchangedPlanDoesNotTouchPendingIntents() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val a = alarm("a", now + 60_000)
        reconciler.reconcile(listOf(a), setOf("a"), emptySet(), now)
        platform.operations.clear()
        reconciler.reconcile(listOf(a), setOf("a"), emptySet(), now)
        assertTrue(platform.operations.isEmpty())
    }

    @Test fun failedReplacementKeepsPreviousRecordAndOtherAlarm() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val a = alarm("a", now + 60_000)
        val b = alarm("b", now + 90_000)
        reconciler.reconcile(listOf(a, b), setOf("a", "b"), emptySet(), now)
        val changed = alarm("a", now + 120_000)
        platform.failures.add(changed.id)
        val failures = reconciler.reconcile(listOf(changed, b), setOf("a", "b"), emptySet(), now)
        assertTrue("a" in failures)
        assertEquals(setOf(a.id, b.id), platform.ids())
    }

    @Test fun missingDataPreservesOnlyItsEnabledRoot() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val a = alarm("a", now + 60_000)
        val b = alarm("b", now + 90_000)
        reconciler.reconcile(listOf(a, b), setOf("a", "b"), emptySet(), now)
        reconciler.reconcile(emptyList(), setOf("a"), setOf("a"), now)
        assertEquals(setOf(a.id), platform.ids())
    }

    @Test fun deletedRootCannotRestartFromLateDelivery() {
        val platform = Platform()
        val missions = AlarmMissions(Memory())
        val reconciler = AlarmReconciler(platform, missions)
        val a = alarm("a", now + 1000)
        reconciler.reconcile(listOf(a), setOf("a"), emptySet(), now)
        assertTrue(missions.fired(a, now + 1000))
        val stopped = missions.stop(a, now + 1100)!!
        val timer = stopped.session.watchdog(now + 31_100)
        platform.accepted[timer.id] = timer
        reconciler.reconcile(emptyList(), emptySet(), emptySet(), now + 1200)
        assertTrue(platform.ids().isEmpty())
        assertFalse(missions.fired(timer, timer.timeMillis))
    }

    @Test fun explicitSkipOverridesDeliveryGuardAndSuppressesCallback() {
        val platform = Platform()
        val missions = AlarmMissions(Memory())
        val reconciler = AlarmReconciler(platform, missions)
        val a = alarm("a", now + 500)
        reconciler.reconcile(listOf(a), setOf("a"), emptySet(), now)
        reconciler.reconcile(emptyList(), setOf("a"), emptySet(), now,
            listOf(AlarmSuppression("a", a.timeMillis)))
        assertTrue(platform.ids().isEmpty())
        assertFalse(missions.fired(a, a.timeMillis))
    }

    @Test fun allNearestOccurrencesPrecedeDistantDays() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val a = alarm("a", now + 60_000)
        val future = alarm("a", now + 86_400_000)
        val b = alarm("b", now + 90_000)
        reconciler.reconcile(listOf(a, future, b), setOf("a", "b"), emptySet(), now)
        assertEquals(listOf("schedule:" + a.id, "schedule:" + b.id),
            platform.operations.take(2))
    }

    @Test fun fixedSkipKeepsWeeklyTemplateAndSuppressesOnlyTheSkippedDelivery() {
        val platform = Platform()
        val missions = AlarmMissions(Memory())
        val reconciler = AlarmReconciler(platform, missions)
        val skipped = alarm("a", now + 60_000)
        val next = alarm("a", skipped.timeMillis + 86_400_000).copy(
            templateWeekdays = listOf(1, 2, 3, 4, 5, 6, 7), repeatHour = 8, repeatMinute = 0)
        val later = next.copy(id = "a#later", timeMillis = next.timeMillis + 86_400_000)
        reconciler.reconcile(listOf(next, later), setOf("a"), emptySet(), now,
            listOf(AlarmSuppression("a", skipped.timeMillis)))
        assertEquals(setOf("a"), platform.ids())
        assertEquals(next.templateWeekdays, platform.accepted["a"]!!.repeatWeekdays)
        assertFalse(missions.fired(skipped, skipped.timeMillis))
        assertTrue(missions.fired(next, next.timeMillis))
    }

    @Test fun editingWeeklyTimeUpdatesTheNativeTemplate() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val old = alarm("a", now + 60_000).copy(id = "a", repeatWeekdays = listOf(1, 5))
        reconciler.reconcile(listOf(old), setOf("a"), emptySet(), now)
        platform.operations.clear()
        val changed = old.copy(timeMillis = old.timeMillis + 60_000)
        reconciler.reconcile(listOf(changed), setOf("a"), emptySet(), now)
        assertEquals(listOf("schedule:a"), platform.operations)
    }

    @Test fun partialCacheKeepsMissingPeriodUpdatesKnownPeriodAndHonorsSkip() {
        val platform = Platform()
        val reconciler = AlarmReconciler(platform, AlarmMissions(Memory()))
        val missing = alarm("a", now + 60_000)
        val known = alarm("a", now + 90_000)
        reconciler.reconcile(listOf(missing, known), setOf("a"), emptySet(), now)
        val changed = alarm("a", now + 120_000)
        val period = AlarmPreservedPeriod("a", now, now + 75_000)
        reconciler.reconcile(listOf(changed), setOf("a"), emptySet(), now, periods = listOf(period))
        assertEquals(setOf(missing.id, changed.id), platform.ids())
        reconciler.reconcile(listOf(changed), setOf("a"), emptySet(), now,
            skips = listOf(AlarmSuppression("a", missing.timeMillis)), periods = listOf(period))
        assertEquals(setOf(changed.id), platform.ids())
    }
}
