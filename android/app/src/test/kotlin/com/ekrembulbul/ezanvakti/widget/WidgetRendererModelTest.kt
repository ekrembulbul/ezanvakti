package com.ekrembulbul.ezanvakti.widget

import com.ekrembulbul.ezanvakti.widget.WidgetViewModel.ColumnState
import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class WidgetRendererModelTest {
    private val dhuhr = WidgetSnapshotModelTest.DHUHR // 2026-10-08 12:57 İstanbul
    private val kerahatStart = dhuhr - 600_000 // 12:47
    private val zone = TimeZone.getTimeZone("Europe/Istanbul")
    private val tr = Locale.forLanguageTag("tr")
    private val palette = WidgetPalette.resolve(WidgetAppearance.FALLBACK, Phase.MORNING, systemDark = true)

    private fun snapshot(timeline: String, days: String = WidgetSnapshotModelTest.dayJson()): WidgetSnapshot =
        (WidgetSnapshotParser.parse(WidgetSnapshotModelTest.snapshotJson(days, timeline)) as SnapshotResult.Ok).snapshot

    private fun model(snapshot: WidgetSnapshot, now: Long): WidgetViewModel {
        val state = WidgetTimeline.state(snapshot, now)!!
        return WidgetViewModel.from(state, snapshot, palette, "h24", system24 = true, locale = tr, now = now, zone = zone)
    }

    private fun entry(at: Long, slot: Int = 2, day: Int = 0, tomorrow: Boolean = false, kerahat: String = "null") =
        """{"at": $at, "day": $day, "slot": $slot, "tomorrow": $tomorrow, "phase": "morning", "kerahat": $kerahat}"""

    private fun kerahat(state: String) = """{"state": "$state", "start": $kerahatStart, "end": $dhuhr}"""

    @Test fun normalStateTexts() {
        val now = dhuhr - 3_600_000
        val m = model(snapshot("[${entry(now)}]"), now)
        assertEquals("ÖĞLE", m.nameText)
        assertEquals("12:57", m.timeText)
        assertEquals(dhuhr, m.countdownTargetMillis)
        assertEquals("İstanbul (Merkez) · 8 Ekim", m.smallTop)
        assertEquals("İstanbul (Merkez)", m.mediumLocation)
        assertEquals("Perşembe, 8 Ekim · 27 Rebiülahir", m.mediumDate)
        assertEquals(listOf("Perşembe", "27 Rebiülahir 1448"), m.bottomLines)
        assertNull(m.kerahat)
        assertEquals(palette.accent, m.nameColor)
        assertEquals(palette.textPrimary, m.countdownColor)
        assertFalse(m.stale)
        assertNotNull(m.nowFraction)
    }

    @Test fun tomorrowPrefixesNameAndHidesDot() {
        val days = WidgetSnapshotModelTest.dayJson() + "," +
            WidgetSnapshotModelTest.dayJson(date = "2026-10-09", base = dhuhr + 86_400_000)
        val afterIsha = dhuhr + 25_000_000 + 60_000
        val m = model(snapshot("[${entry(afterIsha, slot = 0, day = 1, tomorrow = true)}]", days), afterIsha)
        assertEquals("YARIN · İMSAK", m.nameText)
        assertEquals(dhuhr + 86_400_000 - 26_000_000, m.countdownTargetMillis)
        // Gösterilen gün yarın: cetvel noktası ve saat etiketi yok.
        assertNull(m.nowFraction)
        assertTrue(m.columns.drop(1).all { it.state == ColumnState.FUTURE })
        assertEquals(ColumnState.NEXT, m.columns[0].state)
    }

    @Test fun approachingKerahatShowsCardTowardStart() {
        val now = kerahatStart - 1_800_000
        val m = model(snapshot("[${entry(now, kerahat = kerahat("approaching"))}]"), now)
        val k = m.kerahat!!
        assertEquals("Kerahate", k.word)
        assertEquals("12:47 – 12:57", k.rangeText)
        assertEquals(kerahatStart, k.targetMillis)
        assertFalse(k.active)
        assertEquals(palette.soonSurface, k.surface)
        assertEquals(palette.soonText, k.text)
        // Yaklaşırken vakit adı ve sayaç normal renkte; orta boyda tarih yerine çip.
        assertEquals(palette.accent, m.nameColor)
        assertEquals(palette.textPrimary, m.countdownColor)
        assertNull(m.mediumDate)
        assertEquals(dhuhr, m.countdownTargetMillis)
    }

    @Test fun activeKerahatTurnsNameAndCountdownBurgundy() {
        val m = model(snapshot("[${entry(kerahatStart, kerahat = kerahat("active"))}]"), kerahatStart + 1_000)
        val k = m.kerahat!!
        assertEquals("Kerahat", k.word)
        assertEquals(dhuhr, k.targetMillis)
        assertTrue(k.active)
        assertEquals(palette.kerahatSurface, k.surface)
        assertEquals(palette.kerahatText, k.text)
        assertEquals(palette.kerahatText, m.nameColor)
        assertEquals(palette.kerahatText, m.countdownColor)
        assertNull(m.mediumDate)
    }

    @Test fun mediumDateSkipsMissingParts() {
        val day = WidgetSnapshotModelTest.dayJson().replace("\"weekday\": \"Perşembe\",", "")
        val now = dhuhr - 3_600_000
        val m = model(snapshot("[${entry(now)}]", day), now)
        assertEquals("8 Ekim · 27 Rebiülahir", m.mediumDate)
        assertEquals(listOf("27 Rebiülahir 1448"), m.bottomLines)
    }

    @Test fun columnsMarkPastNextFuture() {
        val now = dhuhr - 3_600_000
        val m = model(snapshot("[${entry(now)}]"), now)
        assertEquals(
            listOf(ColumnState.PAST, ColumnState.PAST, ColumnState.NEXT,
                ColumnState.FUTURE, ColumnState.FUTURE, ColumnState.FUTURE),
            m.columns.map { it.state },
        )
        assertEquals("Öğle", m.columns[2].name)
        assertEquals("12:57", m.columns[2].time)
        assertEquals("05:43", m.columns[0].time)
    }

    @Test fun twelveHourPreferenceFormatsTimes() {
        val now = dhuhr - 3_600_000
        val s = snapshot("[${entry(now)}]")
        val state = WidgetTimeline.state(s, now)!!
        val m = WidgetViewModel.from(state, s, palette, "h12", system24 = true, locale = Locale.US, now = now, zone = zone)
        assertEquals("12:57 PM", m.timeText)
    }

    @Test fun staleShowsLabelAndDropsKerahat() {
        val entryAt = kerahatStart - 1_800_000
        val afterDhuhr = dhuhr + 1
        val m = model(snapshot("[${entry(entryAt, kerahat = kerahat("approaching"))}]"), afterDhuhr)
        assertTrue(m.stale)
        assertEquals("Güncel değil", m.smallTop)
        assertEquals("Güncel değil", m.mediumLocation)
        assertNull(m.kerahat)
        assertEquals(listOf("Perşembe", "27 Rebiülahir 1448"), m.bottomLines)
    }
}
