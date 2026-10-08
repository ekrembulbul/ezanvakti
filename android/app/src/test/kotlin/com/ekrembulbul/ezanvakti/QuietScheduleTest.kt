package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class QuietScheduleTest {
    private val a = QuietInterval(1_000, 2_000)
    private val b = QuietInterval(5_000, 6_000)

    @Test fun parseDropsInvalidAndSorts() {
        val parsed = QuietSchedule.parse(listOf(
            mapOf("startMillis" to 5_000L, "endMillis" to 6_000L),
            mapOf("startMillis" to 2_000, "endMillis" to 1_000),
            mapOf("startMillis" to "x"),
            mapOf("startMillis" to 1_000, "endMillis" to 2_000),
        ))
        assertEquals(listOf(a, b), parsed)
    }
    @Test fun jsonRoundTrip() {
        assertEquals(listOf(a, b), QuietSchedule.decode(QuietSchedule.encode(listOf(a, b))))
        assertEquals(emptyList<QuietInterval>(), QuietSchedule.decode(null))
        assertEquals(emptyList<QuietInterval>(), QuietSchedule.decode("bozuk"))
    }
    @Test fun insideIsStartInclusiveEndExclusive() {
        assertTrue(QuietSchedule.isInside(listOf(a), 1_000))
        assertFalse(QuietSchedule.isInside(listOf(a), 2_000))
    }
    @Test fun nextBoundaryIsNearestFutureEdge() {
        assertEquals(1_000L, QuietSchedule.nextBoundary(listOf(a, b), 0))
        assertEquals(2_000L, QuietSchedule.nextBoundary(listOf(a, b), 1_500))
        assertEquals(5_000L, QuietSchedule.nextBoundary(listOf(a, b), 2_000))
        assertNull(QuietSchedule.nextBoundary(listOf(a, b), 6_000))
    }
    @Test fun pruneKeepsRunningInterval() {
        assertEquals(listOf(b), QuietSchedule.prune(listOf(a, b), 2_000))
        assertEquals(listOf(a, b), QuietSchedule.prune(listOf(a, b), 1_500))
    }
    @Test fun decideWritesOnlyOnChange() {
        // Kullanıcı pencere içinde DND'yi elle kapattıysa uygulanan durum hâlâ
        // "açık"tır; yeniden açma yazılmaz (D6).
        assertNull(QuietSchedule.decide(desired = true, applied = true))
        assertEquals(true, QuietSchedule.decide(desired = true, applied = false))
        assertEquals(false, QuietSchedule.decide(desired = false, applied = true))
        assertNull(QuietSchedule.decide(desired = false, applied = false))
    }
}
