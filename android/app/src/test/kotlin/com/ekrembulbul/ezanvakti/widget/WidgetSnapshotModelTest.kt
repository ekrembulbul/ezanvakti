package com.ekrembulbul.ezanvakti.widget

import org.junit.Assert.*
import org.junit.Test

class WidgetSnapshotModelTest {
    companion object {
        const val DHUHR = 1_791_453_420_000L

        fun dayJson(date: String = "2026-10-08", base: Long = DHUHR, epochs: Boolean = true): String {
            val e = if (!epochs) "" else """
              "epochs": {"fajr": ${base - 26_000_000}, "sunrise": ${base - 21_000_000}, "dhuhr": $base,
                         "asr": ${base + 11_000_000}, "maghrib": ${base + 20_000_000}, "isha": ${base + 25_000_000}},"""
            return """{"date": "$date", "hijri": "27 Rebiülahir 1448", "weekday": "Perşembe", "dateLabel": "8 Ekim",
              "hijriShort": "27 Rebiülahir", $e
              "ruler": {"segments": [{"start": 0.0, "end": 0.23, "kind": "night", "gapBefore": false, "gapAfter": true},
                                     {"start": 0.23, "end": 0.5, "kind": "bogus", "gapBefore": true, "gapAfter": false}],
                        "marks": [0.23, 0.29, 0.54, 0.67, 0.78, 0.83]},
              "times": {"fajr": "05:36"}, "kerahat": []}"""
        }

        fun snapshotJson(days: String = dayJson(), timeline: String? = null): String {
            val t = timeline ?: """[{"at": ${DHUHR - 600_000}, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning",
                "kerahat": {"state": "approaching", "start": ${DHUHR - 600_000}, "end": $DHUHR}}]"""
            return """{"schemaVersion": 4, "locationLabel": "İstanbul (Merkez)",
              "labels": {"dhuhr": "Öğle", "kerahat": "Kerahat", "kerahatSoon": "Kerahate", "tomorrow": "Yarın"},
              "days": [$days], "timeline": $t}"""
        }
    }

    @Test fun parsesContract() {
        val result = WidgetSnapshotParser.parse(snapshotJson()) as SnapshotResult.Ok
        val s = result.snapshot
        assertEquals("İstanbul (Merkez)", s.locationLabel)
        val day = s.days.single()
        assertEquals("Perşembe", day.weekday)
        assertEquals("27 Rebiülahir", day.hijriShort)
        assertEquals(6, day.slots.size)
        assertEquals("Öğle", day.slots[2].name)
        assertEquals("İmsak", day.slots[0].name) // etiket yok → Türkçe varsayılan
        assertEquals(DHUHR, day.slots[2].epochMillis)
        assertEquals(1, day.ruler.size) // bilinmeyen tür atlandı
        assertEquals(6, day.marks.size)
        val entry = s.timeline.single()
        assertEquals(Phase.MORNING, entry.phase)
        assertFalse(entry.kerahat!!.active)
        assertEquals(DHUHR - 600_000, entry.kerahat!!.targetMillis)
    }

    @Test fun missingOrBrokenPayloadIsNoData() {
        assertEquals(SnapshotResult.NoData, WidgetSnapshotParser.parse(null))
        assertEquals(SnapshotResult.NoData, WidgetSnapshotParser.parse("bozuk"))
        // Zaman çizelgesi olmayan eski uygulama.
        assertEquals(SnapshotResult.NoData, WidgetSnapshotParser.parse(snapshotJson(timeline = "[]")))
    }

    @Test fun dayWithoutEpochsKeepsIndexButDropsItsEntries() {
        val days = dayJson(epochs = false) + "," + dayJson(date = "2026-10-09", base = DHUHR + 86_400_000)
        val timeline = """[{"at": 1, "day": 0, "slot": 2, "tomorrow": false, "phase": "night", "kerahat": null},
                          {"at": 2, "day": 1, "slot": 0, "tomorrow": true, "phase": "night", "kerahat": null}]"""
        val s = (WidgetSnapshotParser.parse(snapshotJson(days, timeline)) as SnapshotResult.Ok).snapshot
        assertEquals(2, s.days.size)
        assertTrue(s.days[0].slots.isEmpty())
        assertEquals(listOf(1), s.timeline.map { it.dayIndex })
    }

    @Test fun invalidEntriesAreDroppedAndSorted() {
        val timeline = """[{"at": 300, "day": 0, "slot": 1, "tomorrow": false, "phase": "morning", "kerahat": null},
                          {"at": 100, "day": 0, "slot": 0, "tomorrow": false, "phase": "night", "kerahat": null},
                          {"at": 200, "day": 5, "slot": 0, "tomorrow": false, "phase": "night", "kerahat": null},
                          {"at": 250, "day": 0, "slot": 9, "tomorrow": false, "phase": "night", "kerahat": null},
                          {"at": 260, "day": 0, "slot": 1, "tomorrow": false, "phase": "noon", "kerahat": null}]"""
        val s = (WidgetSnapshotParser.parse(snapshotJson(timeline = timeline)) as SnapshotResult.Ok).snapshot
        assertEquals(listOf(100L, 300L), s.timeline.map { it.atMillis })
    }
}
