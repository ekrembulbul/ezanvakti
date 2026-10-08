package com.ekrembulbul.ezanvakti.widget

import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class NextPrayerContentTest {
    private val dhuhr = WidgetSnapshotModelTest.DHUHR // 2026-10-08 12:57 İstanbul
    private val kerahatStart = dhuhr - 600_000 // 12:47
    private val zone = TimeZone.getTimeZone("Europe/Istanbul")
    private val tr = Locale("tr", "TR")
    private val palette = WidgetPalette.resolve(WidgetAppearance.FALLBACK, Phase.MORNING, true)

    private fun snapshot(timeline: String, days: String = WidgetSnapshotModelTest.dayJson()): WidgetSnapshot =
        (WidgetSnapshotParser.parse(WidgetSnapshotModelTest.snapshotJson(days, timeline)) as SnapshotResult.Ok).snapshot

    private fun content(
        s: WidgetSnapshot,
        now: Long,
        timePref: String? = "h24",
        locale: Locale = tr,
    ): NextPrayerContent {
        val state = WidgetTimeline.state(s, now)!!
        return NextPrayerContent.from(state, s, palette, timePref, true, locale, now, zone)
    }

    /** Öğle'ye giden üç dilim: normal, kerahat yaklaşıyor, kerahatte. */
    private val dhuhrTimeline = """[
        {"at": ${dhuhr - 10_800_000}, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning", "kerahat": null},
        {"at": ${kerahatStart - 1_800_000}, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning",
         "kerahat": {"state": "approaching", "start": $kerahatStart, "end": $dhuhr}},
        {"at": $kerahatStart, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning",
         "kerahat": {"state": "active", "start": $kerahatStart, "end": $dhuhr}}]"""

    @Test fun normalShowsLocationAndNoCard() {
        val c = content(snapshot(dhuhrTimeline), dhuhr - 7_200_000)
        assertEquals("İstanbul (Merkez)", c.subText)
        assertNull(c.headerChronometerTarget)
        assertEquals(palette.accent, c.accentColor)
        assertEquals(palette.accent, c.highlightColor)
        assertEquals(palette.accent, c.nameColor)
        assertNull(c.countdownColor)
        assertNull(c.card)
        assertEquals("ÖĞLE", c.nameText)
        assertEquals("12:57", c.timeText)
        assertEquals(dhuhr, c.countdownTarget)
    }

    @Test fun approachingCountsToStartInOrange() {
        val c = content(snapshot(dhuhrTimeline), kerahatStart - 60_000)
        assertEquals("Kerahate", c.subText)
        assertEquals(kerahatStart, c.headerChronometerTarget)
        assertEquals(palette.soonLine, c.accentColor)
        val card = c.card!!
        assertEquals("Kerahate", card.word)
        assertEquals("12:47 – 12:57", card.rangeText)
        assertEquals(kerahatStart, card.targetMillis)
        assertFalse(card.active)
        assertEquals(palette.soonSurface, card.surfaceColor)
        assertEquals(palette.soonText, card.textColor)
        // Büyük sayaç kerahatte de vakte sayar; yaklaşırken satır rengi değişmez.
        assertEquals(dhuhr, c.countdownTarget)
        assertEquals(palette.accent, c.nameColor)
        assertNull(c.countdownColor)
    }

    @Test fun activeCountsToEndInBordeaux() {
        val c = content(snapshot(dhuhrTimeline), kerahatStart + 60_000)
        assertEquals("Kerahat", c.subText)
        assertEquals(dhuhr, c.headerChronometerTarget)
        assertEquals(palette.kerahatLine, c.accentColor)
        val card = c.card!!
        assertEquals("Kerahat", card.word)
        assertEquals(dhuhr, card.targetMillis)
        assertTrue(card.active)
        assertEquals(palette.kerahatSurface, card.surfaceColor)
        assertEquals(palette.kerahatText, card.textColor)
        // Kapalı bildirimde başlık yok: kerahat satır renginden anlaşılır.
        assertEquals(palette.kerahatText, c.nameColor)
        assertEquals(palette.kerahatText, c.countdownColor)
    }

    @Test fun columnsMarkPastNextFuture() {
        val c = content(snapshot(dhuhrTimeline), dhuhr - 7_200_000)
        assertEquals(6, c.columns.size)
        assertEquals(listOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"), c.columns.map { it.name })
        assertEquals(
            listOf(
                NextPrayerContent.Status.PAST, NextPrayerContent.Status.PAST, NextPrayerContent.Status.NEXT,
                NextPrayerContent.Status.FUTURE, NextPrayerContent.Status.FUTURE, NextPrayerContent.Status.FUTURE,
            ),
            c.columns.map { it.status },
        )
        assertEquals("05:43", c.columns[0].timeText)
        assertEquals("12:57", c.columns[2].timeText)
    }

    @Test fun rulerCarriesDayAndNowOnShownDay() {
        val now = dhuhr - 7_200_000
        val c = content(snapshot(dhuhrTimeline), now)
        val s = snapshot(dhuhrTimeline)
        assertEquals(s.days[0].ruler, c.ruler.parts)
        assertEquals(s.days[0].marks, c.ruler.marks)
        assertEquals(WidgetTimeline.nowFraction(s.days[0], now, zone)!!, c.ruler.nowFraction!!, 0.0001f)
    }

    @Test fun tomorrowPrefixesNameAndHidesNow() {
        val days = WidgetSnapshotModelTest.dayJson() + "," +
            WidgetSnapshotModelTest.dayJson(date = "2026-10-09", base = dhuhr + 86_400_000)
        val afterIsha = dhuhr + 25_000_001
        val timeline = """[{"at": $afterIsha, "day": 1, "slot": 0, "tomorrow": true, "phase": "night", "kerahat": null}]"""
        val c = content(snapshot(timeline, days), afterIsha)
        assertEquals("YARIN · İMSAK", c.nameText)
        assertNull(c.card)
        // Gösterilen gün yarın: nokta ve saat etiketi yok, geçmiş sütun yok.
        assertNull(c.ruler.nowFraction)
        assertEquals(NextPrayerContent.Status.NEXT, c.columns[0].status)
        assertTrue(c.columns.drop(1).all { it.status == NextPrayerContent.Status.FUTURE })
    }

    @Test fun twelveHourKeepsMarkerInRowButNotInColumns() {
        val c = content(snapshot(dhuhrTimeline), kerahatStart - 60_000, timePref = "h12", locale = Locale.US)
        assertEquals("12:57 PM", c.timeText)
        assertEquals("12:47 PM – 12:57 PM", c.card!!.rangeText)
        assertEquals("12:57", c.columns[2].timeText)
        assertEquals("5:43", c.columns[0].timeText)
    }
}
