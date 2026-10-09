package com.ekrembulbul.ezanvakti.widget

import java.util.Locale
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class WidgetPaletteTest {
    @Test fun followsThemeModeAndPhase() {
        val system = WidgetAppearance.FALLBACK
        assertEquals(0xFF93C4E8.toInt(), WidgetPalette.resolve(system, Phase.MORNING, systemDark = true).accent)
        assertFalse(WidgetPalette.resolve(system, Phase.MORNING, systemDark = false).isDark)
        val dark = WidgetAppearance("dark", true, Phase.EVENING)
        assertTrue(WidgetPalette.resolve(dark, Phase.MORNING, systemDark = false).isDark)
    }

    @Test fun fixedPaletteIgnoresTimeBasedPhase() {
        val fixed = WidgetAppearance("light", false, Phase.NIGHT)
        val palette = WidgetPalette.resolve(fixed, Phase.MORNING, systemDark = true)
        assertEquals(0xFFD6C8E4.toInt(), palette.stops[0])
    }

    @Test fun appearanceParsesWithFieldFallbacks() {
        assertEquals(WidgetAppearance.FALLBACK, WidgetAppearance.parse(null))
        assertEquals(WidgetAppearance.FALLBACK, WidgetAppearance.parse("bozuk"))
        val parsed = WidgetAppearance.parse("""{"themeMode": "neon", "timeBasedColor": false, "fixedPalette": "night"}""")
        assertEquals("system", parsed.themeMode)
        assertFalse(parsed.timeBasedColor)
        assertEquals(Phase.NIGHT, parsed.fixedPalette)
    }

    @Test fun kerahatColorsFollowDarkness() {
        val dark = WidgetPalette.resolve(WidgetAppearance("dark", true, Phase.EVENING), Phase.EVENING, true)
        val light = WidgetPalette.resolve(WidgetAppearance("light", true, Phase.EVENING), Phase.EVENING, true)
        assertEquals(0xFFA14158.toInt(), dark.kerahatLine)
        assertEquals(0xFFFDEFE1.toInt(), light.soonSurface)
        assertEquals(0xFF4A2D14.toInt(), dark.soonFill)
        assertEquals(0xFFFADFC2.toInt(), light.soonFill)
    }

    @Test fun kerahatTintPullsEveryStopTowardWine() {
        val dark = WidgetPalette.resolve(WidgetAppearance("dark", true, Phase.EVENING), Phase.EVENING, true)
        val light = WidgetPalette.resolve(WidgetAppearance("light", true, Phase.EVENING), Phase.EVENING, true)
        // 0x4A2144 → 0x6A2238 %88: (102, 34, 57)
        assertEquals(0xFF662239.toInt(), dark.withKerahatTint().stops[0])
        // 0xEFCBD6 → 0xE8B3C0 %88: (233, 182, 195)
        assertEquals(0xFFE9B6C3.toInt(), light.withKerahatTint().stops[0])
        assertEquals(3, dark.withKerahatTint().stops.size)
        // Renkler ve koyuluk aynı kalır; yalnız zemin döner, asıl palet değişmez.
        assertEquals(dark.accent, dark.withKerahatTint().accent)
        assertEquals(dark.isDark, dark.withKerahatTint().isDark)
        assertEquals(0xFF4A2144.toInt(), dark.stops[0])
    }

    @Test fun mixIsPerChannelAndOpaque() {
        assertEquals(0xFF000000.toInt(), Palette.mix(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 0f))
        assertEquals(0xFFFFFFFF.toInt(), Palette.mix(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 1f))
        assertEquals(0xFF808080.toInt(), Palette.mix(0xFF000000.toInt(), 0xFFFFFFFF.toInt(), 0.5f))
    }
}

class WidgetTimeFormatTest {
    private val zone = TimeZone.getTimeZone("Europe/Istanbul")
    private val at1257 = java.util.Calendar.getInstance(zone).apply { clear(); set(2026, 9, 8, 12, 57, 0) }.timeInMillis
    private val at2002 = at1257 + (7 * 60 + 5) * 60_000L

    @Test fun followsPreference() {
        assertEquals("12:57", WidgetTimeFormat.format(at1257, "h24", system24 = false, locale = Locale.US, zone = zone))
        assertEquals("8:02 PM", WidgetTimeFormat.format(at2002, "h12", system24 = true, locale = Locale.US, zone = zone))
        assertEquals("20:02", WidgetTimeFormat.format(at2002, "system", system24 = true, locale = Locale.US, zone = zone))
        assertEquals("8:02 PM", WidgetTimeFormat.format(at2002, null, system24 = false, locale = Locale.US, zone = zone))
    }
}
