package com.ekrembulbul.ezanvakti.widget

import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class WidgetTimelineTest {
    private val dhuhr = WidgetSnapshotModelTest.DHUHR
    private val asr = dhuhr + 11_000_000

    private fun snapshot(): WidgetSnapshot {
        val timeline = """[{"at": ${dhuhr - 3_600_000}, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning", "kerahat": null},
                          {"at": $dhuhr, "day": 0, "slot": 3, "tomorrow": false, "phase": "afternoon", "kerahat": null}]"""
        return (WidgetSnapshotParser.parse(WidgetSnapshotModelTest.snapshotJson(timeline = timeline)) as SnapshotResult.Ok).snapshot
    }

    @Test fun picksEntryValidAtNow() {
        val s = snapshot()
        assertEquals(SlotKey.DHUHR, WidgetTimeline.state(s, dhuhr - 1)!!.next.key)
        assertEquals(SlotKey.ASR, WidgetTimeline.state(s, dhuhr)!!.next.key)
        assertFalse(WidgetTimeline.state(s, dhuhr)!!.stale)
    }

    @Test fun beforeFirstEntryShowsFirst() {
        assertEquals(SlotKey.DHUHR, WidgetTimeline.state(snapshot(), 0)!!.next.key)
    }

    @Test fun afterLastSlotIsStale() {
        val state = WidgetTimeline.state(snapshot(), asr + 1)!!
        assertTrue(state.stale)
        assertEquals(SlotKey.ASR, state.next.key)
    }

    @Test fun nextBoundaryIsNextEntryThenLastSlot() {
        val s = snapshot()
        assertEquals(dhuhr, WidgetTimeline.nextBoundary(s, dhuhr - 10))
        assertEquals(asr, WidgetTimeline.nextBoundary(s, dhuhr))
        assertNull(WidgetTimeline.nextBoundary(s, asr))
    }

    @Test fun nowFractionOnlyInsideShownDay() {
        val zone = TimeZone.getTimeZone("Europe/Istanbul")
        val day = snapshot().days[0] // 2026-10-08
        val noon = java.util.Calendar.getInstance(zone).apply { clear(); set(2026, 9, 8, 12, 0, 0) }.timeInMillis
        assertEquals(0.5f, WidgetTimeline.nowFraction(day, noon, zone)!!, 0.001f)
        assertNull(WidgetTimeline.nowFraction(day, noon + 86_400_000, zone))
        assertNull(WidgetTimeline.nowFraction(day, noon - 86_400_000, zone))
    }
}
