package com.ekrembulbul.ezanvakti

import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject

/** Çalar ekranın renkleri. Dart tarafı, alarmın çalacağı anın dilimine göre
 *  (ÇİVİT / KURŞUNİ / ERGUVAN / SÜMBÜL) hesaplayıp `#RRGGBB` olarak gönderir.
 *
 *  Reboot sonrası yeniden kurulan eski alarmlarda tema kayıtlı olmayabilir;
 *  o durumda [FALLBACK] kullanılır. */
data class AlarmTheme(
    val accent: Int,
    val backgroundStops: List<Int>,
    val textPrimary: Int,
    val textSecondary: Int,
) {
    fun toJson(): String = JSONObject().apply {
        put(KEY_ACCENT, hex(accent))
        put(KEY_STOPS, JSONArray(backgroundStops.map { hex(it) }))
        put(KEY_TEXT_PRIMARY, hex(textPrimary))
        put(KEY_TEXT_SECONDARY, hex(textSecondary))
    }.toString()

    companion object {
        private const val KEY_ACCENT = "accent"
        private const val KEY_STOPS = "backgroundStops"
        private const val KEY_TEXT_PRIMARY = "textPrimary"
        private const val KEY_TEXT_SECONDARY = "textSecondary"

        /** ERGUVAN (koyu) — Dart tarafındaki `fallbackDayPhase` ile aynı palet. */
        val FALLBACK = AlarmTheme(
            accent = 0xFFE09FB8.toInt(),
            backgroundStops = listOf(0xFF4A2144.toInt(), 0xFF241634.toInt(), 0xFF120E1B.toInt()),
            textPrimary = 0xFFF3EEF4.toInt(),
            textSecondary = 0xFFB5A8C1.toInt(),
        )

        fun fromJson(json: String?): AlarmTheme {
            if (json.isNullOrBlank()) return FALLBACK
            return try {
                val o = JSONObject(json)
                val stops = o.optJSONArray(KEY_STOPS)
                AlarmTheme(
                    accent = parse(o.optString(KEY_ACCENT), FALLBACK.accent),
                    backgroundStops = readStops(stops),
                    textPrimary = parse(o.optString(KEY_TEXT_PRIMARY), FALLBACK.textPrimary),
                    textSecondary = parse(o.optString(KEY_TEXT_SECONDARY), FALLBACK.textSecondary),
                )
            } catch (_: Exception) {
                FALLBACK
            }
        }

        /** Flutter method channel'dan gelen `Map` gösterimi. */
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<*, *>?): AlarmTheme {
            if (map == null) return FALLBACK
            val stops = (map[KEY_STOPS] as? List<*>)
                ?.mapNotNull { it as? String }
                ?.map { parse(it, FALLBACK.accent) }
                ?: emptyList()
            return AlarmTheme(
                accent = parse(map[KEY_ACCENT] as? String, FALLBACK.accent),
                backgroundStops = if (stops.size >= 2) stops else FALLBACK.backgroundStops,
                textPrimary = parse(map[KEY_TEXT_PRIMARY] as? String, FALLBACK.textPrimary),
                textSecondary = parse(map[KEY_TEXT_SECONDARY] as? String, FALLBACK.textSecondary),
            )
        }

        private fun readStops(array: JSONArray?): List<Int> {
            if (array == null || array.length() < 2) return FALLBACK.backgroundStops
            val out = ArrayList<Int>(array.length())
            for (i in 0 until array.length()) {
                out.add(parse(array.optString(i), FALLBACK.backgroundStops.last()))
            }
            return out
        }

        /** Bozuk bir renk dizesi cihazda alarmı patlatmamalı; varsayılana düşer. */
        private fun parse(value: String?, fallback: Int): Int = try {
            if (value.isNullOrBlank()) fallback else Color.parseColor(value)
        } catch (_: IllegalArgumentException) {
            fallback
        }

        private fun hex(color: Int): String = String.format("#%06X", color and 0xFFFFFF)
    }
}
