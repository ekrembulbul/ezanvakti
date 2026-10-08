package com.ekrembulbul.ezanvakti.widget

import org.json.JSONObject

/** Uygulamanın Görünüm ayarlarının widget'a taşınan kopyası (iOS `WidgetAppearance`). */
data class WidgetAppearance(
    /** `dark`, `light` ya da `system`. */
    val themeMode: String,
    val timeBasedColor: Boolean,
    val fixedPalette: Phase,
) {
    fun phase(timeBased: Phase): Phase = if (timeBasedColor) timeBased else fixedPalette

    fun isDark(systemDark: Boolean): Boolean = when (themeMode) {
        "dark" -> true
        "light" -> false
        else -> systemDark
    }

    companion object {
        val FALLBACK = WidgetAppearance("system", true, Phase.FALLBACK)

        /** Tek bozuk alan yalnız kendini varsayılana düşürür. */
        fun parse(json: String?): WidgetAppearance {
            if (json.isNullOrBlank()) return FALLBACK
            return try {
                val o = JSONObject(json)
                WidgetAppearance(
                    themeMode = o.optString("themeMode").takeIf { it in setOf("dark", "light", "system") }
                        ?: FALLBACK.themeMode,
                    timeBasedColor = if (o.has("timeBasedColor")) o.optBoolean("timeBasedColor", true)
                    else FALLBACK.timeBasedColor,
                    fixedPalette = Phase.from(o.optString("fixedPalette")) ?: FALLBACK.fixedPalette,
                )
            } catch (_: Exception) {
                FALLBACK
            }
        }
    }
}

/** Bir dilimin widget renkleri; değerler iOS `Palette.swift` ile birebir. */
data class Palette(
    val accent: Int,
    val textPrimary: Int,
    val textSecondary: Int,
    /** Kerahat metni (vakit adı ve sayaç kerahatte bu tona döner). */
    val kerahatText: Int,
    val stops: IntArray,
    val isDark: Boolean,
) {
    val kerahatLine: Int get() = if (isDark) 0xFFA14158.toInt() else 0xFF8D243B.toInt()
    val kerahatSurface: Int get() = if (isDark) 0xFF3C1F2A.toInt() else 0xFFF9E9EC.toInt()
    val soonLine: Int get() = if (isDark) 0xFFE0832E.toInt() else 0xFFC9681C.toInt()
    val soonSurface: Int get() = if (isDark) 0xFF3B2412.toInt() else 0xFFFDEFE1.toInt()
    val soonText: Int get() = if (isDark) 0xFFFFB45C.toInt() else 0xFFA9540E.toInt()
    val divider: Int get() = withAlpha(textSecondary, if (isDark) 0.4f else 0.3f)
    /** Cetvelin gece uçları ve çentikleri (ana ekrandaki gibi soluk). */
    val night: Int get() = withAlpha(textSecondary, 0.4f)
    val tick: Int get() = withAlpha(textSecondary, 0.7f)

    override fun equals(other: Any?): Boolean = other is Palette && accent == other.accent &&
        textPrimary == other.textPrimary && textSecondary == other.textSecondary &&
        kerahatText == other.kerahatText && stops.contentEquals(other.stops) && isDark == other.isDark

    override fun hashCode(): Int = listOf(accent, textPrimary, textSecondary, kerahatText, isDark).hashCode() * 31 +
        stops.contentHashCode()

    companion object {
        fun withAlpha(color: Int, alpha: Float): Int =
            ((alpha.coerceIn(0f, 1f) * 255).toInt() shl 24) or (color and 0x00FFFFFF)
    }
}

object WidgetPalette {
    /** Görünüm ayarı + hesaplanan dilim + cihazın koyu modu (iOS `Palette.resolve`). */
    fun resolve(appearance: WidgetAppearance, phase: Phase, systemDark: Boolean): Palette {
        val effective = appearance.phase(phase)
        return if (appearance.isDark(systemDark)) dark(effective) else light(effective)
    }

    private fun c(hex: Long): Int = (0xFF000000 or hex).toInt()

    private fun dark(phase: Phase): Palette = when (phase) {
        Phase.MORNING -> Palette(c(0x93C4E8), c(0xE8F0F8), c(0xA5BDD2), c(0xFF9292),
            intArrayOf(c(0x2C5279), c(0x143049), c(0x08141F)), true)
        Phase.AFTERNOON -> Palette(c(0xD8E8EE), c(0xF0F5F7), c(0xAFC3CB), c(0xFF9292),
            intArrayOf(c(0x40525C), c(0x202C33), c(0x10171B)), true)
        Phase.EVENING -> Palette(c(0xE09FB8), c(0xF3EEF4), c(0xB5A8C1), c(0xFF9292),
            intArrayOf(c(0x4A2144), c(0x241634), c(0x120E1B)), true)
        Phase.NIGHT -> Palette(c(0xCDA6E4), c(0xF2ECF6), c(0xB3A5C1), c(0xFF9292),
            intArrayOf(c(0x2A2038), c(0x17111F), c(0x0A080E)), true)
    }

    /** Açık temada duraklar uygulamanınkinden koyu (iOS D33): küçük kutuda
     *  düz beyaz karta dönmesin. */
    private fun light(phase: Phase): Palette = when (phase) {
        Phase.MORNING -> Palette(c(0x265F8E), c(0x0E1D2C), c(0x43596D), c(0x8D243B),
            intArrayOf(c(0xB8D2ED), c(0xDCE9F7), c(0xF3F8FC)), false)
        Phase.AFTERNOON -> Palette(c(0x2A5B68), c(0x0F1C21), c(0x435A62), c(0x8D243B),
            intArrayOf(c(0xC2D8DE), c(0xE2ECF0), c(0xF4F9FA)), false)
        Phase.EVENING -> Palette(c(0x983F62), c(0x201A1E), c(0x5A4A50), c(0x8D243B),
            intArrayOf(c(0xEFCBD6), c(0xF7E7EB), c(0xFCF5F6)), false)
        Phase.NIGHT -> Palette(c(0x5E3A80), c(0x1A1424), c(0x4F4260), c(0x8D243B),
            intArrayOf(c(0xD6C8E4), c(0xEBE4F1), c(0xF8F5FA)), false)
    }
}
