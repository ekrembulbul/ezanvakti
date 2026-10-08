package com.ekrembulbul.ezanvakti.widget

import org.json.JSONArray
import org.json.JSONObject

/** Vakitlerin dile bağlı olmayan kimlikleri; sıra snapshot'taki `slot`
 *  indeksiyle aynı (0 İmsak … 5 Yatsı). */
enum class SlotKey(val json: String, val defaultName: String) {
    FAJR("fajr", "İmsak"),
    SUNRISE("sunrise", "Güneş"),
    DHUHR("dhuhr", "Öğle"),
    ASR("asr", "İkindi"),
    MAGHRIB("maghrib", "Akşam"),
    ISHA("isha", "Yatsı"),
}

data class WidgetSlot(val key: SlotKey, val name: String, val epochMillis: Long)

/** Cetvelin oran uzayındaki (0..1) bir parçası; Dart `buildRulerSegments` çıktısı. */
data class RulerPart(
    val start: Float,
    val end: Float,
    val kind: Kind,
    val gapBefore: Boolean,
    val gapAfter: Boolean,
) {
    enum class Kind { DAY, NIGHT, KERAHAT }
}

/** Snapshot'taki bir gün. Eksik epoch'lu gün boş [slots] taşır: zaman
 *  çizelgesi gün indeksleriyle konuştuğu için gün atlanmaz, kaydırılmaz. */
data class WidgetDay(
    val date: String,
    val weekday: String?,
    val dateLabel: String?,
    val hijri: String?,
    val hijriShort: String?,
    val slots: List<WidgetSlot>,
    val ruler: List<RulerPart>,
    val marks: List<Float>,
)

/** O anki kerahat durumu: yaklaşırken sayaç başlangıca, kerahatte bitişe sayar. */
data class KerahatWindow(val active: Boolean, val startMillis: Long, val endMillis: Long) {
    val targetMillis: Long get() = if (active) endMillis else startMillis
}

/** Palet seçimini belirleyen gün dilimi; ham değerler Dart `DayPhase.name`. */
enum class Phase(val json: String) {
    MORNING("morning"),
    AFTERNOON("afternoon"),
    EVENING("evening"),
    NIGHT("night");

    companion object {
        /** Vakit verisi yokken kullanılan dilim (Dart `fallbackDayPhase`). */
        val FALLBACK = EVENING
        fun from(value: String?): Phase? = entries.firstOrNull { it.json == value }
    }
}

/** Zaman çizelgesinin bir anı: [atMillis]'ten bir sonraki girişe kadar geçerli. */
data class TimelineEntry(
    val atMillis: Long,
    val dayIndex: Int,
    val slotIndex: Int,
    val tomorrow: Boolean,
    val phase: Phase,
    val kerahat: KerahatWindow?,
)

/** Widget'ın kullandığı, uygulamanın dilindeki metinler; yoksa Türkçe. */
data class WidgetLabels(
    val tomorrow: String = "Yarın",
    val stale: String = "Güncel değil",
    val openApp: String = "Vakitler için uygulamayı aç",
    val kerahat: String = "Kerahat",
    val kerahatSoon: String = "Kerahate",
)

data class WidgetSnapshot(
    val locationLabel: String,
    val days: List<WidgetDay>,
    val timeline: List<TimelineEntry>,
    val labels: WidgetLabels,
)

sealed interface SnapshotResult {
    data class Ok(val snapshot: WidgetSnapshot) : SnapshotResult
    data object NoData : SnapshotResult
}

/** Dart `WidgetSnapshot.toJson` çıktısını okur (şema 4 + eklemeli alanlar).
 *
 *  Zaman çizelgesi olmayan payload (eski uygulama) ya da bozuk kök
 *  [SnapshotResult.NoData] olur: widget "uygulamayı aç" der, çökmez. Tek bozuk
 *  gün ya da giriş yalnız kendini düşürür. */
object WidgetSnapshotParser {
    fun parse(json: String?): SnapshotResult {
        if (json.isNullOrBlank()) return SnapshotResult.NoData
        return try {
            val root = JSONObject(json)
            val labels = parseLabels(root.optJSONObject("labels"))
            val names = slotNames(root.optJSONObject("labels"))
            val daysJson = root.optJSONArray("days") ?: return SnapshotResult.NoData
            val days = (0 until daysJson.length()).map { index ->
                parseDay(daysJson.optJSONObject(index), names)
            }
            val timeline = parseTimeline(root.optJSONArray("timeline"), days)
            if (days.isEmpty() || timeline.isEmpty()) return SnapshotResult.NoData
            SnapshotResult.Ok(
                WidgetSnapshot(
                    locationLabel = root.optString("locationLabel", ""),
                    days = days,
                    timeline = timeline,
                    labels = labels,
                ),
            )
        } catch (_: Exception) {
            SnapshotResult.NoData
        }
    }

    private fun parseLabels(json: JSONObject?): WidgetLabels {
        val defaults = WidgetLabels()
        if (json == null) return defaults
        fun text(key: String, fallback: String) =
            json.optString(key, "").takeIf { it.isNotBlank() } ?: fallback
        return WidgetLabels(
            tomorrow = text("tomorrow", defaults.tomorrow),
            stale = text("stale", defaults.stale),
            openApp = text("openApp", defaults.openApp),
            kerahat = text("kerahat", defaults.kerahat),
            kerahatSoon = text("kerahatSoon", defaults.kerahatSoon),
        )
    }

    private fun slotNames(json: JSONObject?): Map<SlotKey, String> = SlotKey.entries.associateWith { key ->
        json?.optString(key.json, "")?.takeIf { it.isNotBlank() } ?: key.defaultName
    }

    private fun parseDay(json: JSONObject?, names: Map<SlotKey, String>): WidgetDay {
        if (json == null) return WidgetDay("", null, null, null, null, emptyList(), emptyList(), emptyList())
        val epochs = json.optJSONObject("epochs")
        val slots = if (epochs == null) emptyList() else SlotKey.entries.mapNotNull { key ->
            if (epochs.isNull(key.json) || !epochs.has(key.json)) return@mapNotNull null
            val millis = epochs.optLong(key.json, -1)
            if (millis <= 0) null else WidgetSlot(key, names.getValue(key), millis)
        }.takeIf { it.size == SlotKey.entries.size } ?: emptyList()
        val ruler = json.optJSONObject("ruler")
        return WidgetDay(
            date = json.optString("date", ""),
            weekday = json.optNullableString("weekday"),
            dateLabel = json.optNullableString("dateLabel"),
            hijri = json.optNullableString("hijri"),
            hijriShort = json.optNullableString("hijriShort"),
            slots = slots,
            ruler = parseRuler(ruler?.optJSONArray("segments")),
            marks = parseMarks(ruler?.optJSONArray("marks")),
        )
    }

    private fun parseRuler(array: JSONArray?): List<RulerPart> {
        if (array == null) return emptyList()
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val start = item.optDouble("start", Double.NaN).toFloat()
            val end = item.optDouble("end", Double.NaN).toFloat()
            val kind = when (item.optString("kind")) {
                "day" -> RulerPart.Kind.DAY
                "night" -> RulerPart.Kind.NIGHT
                "kerahat" -> RulerPart.Kind.KERAHAT
                else -> return@mapNotNull null
            }
            if (!start.isFinite() || !end.isFinite() || start < 0f || end > 1f || end <= start) null
            else RulerPart(start, end, kind, item.optBoolean("gapBefore"), item.optBoolean("gapAfter"))
        }
    }

    private fun parseMarks(array: JSONArray?): List<Float> {
        if (array == null) return emptyList()
        return (0 until array.length()).mapNotNull { index ->
            val value = array.optDouble(index, Double.NaN).toFloat()
            if (value.isFinite() && value in 0f..1f) value else null
        }
    }

    private fun parseTimeline(array: JSONArray?, days: List<WidgetDay>): List<TimelineEntry> {
        if (array == null) return emptyList()
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val at = item.optLong("at", -1)
            val day = item.optInt("day", -1)
            val slot = item.optInt("slot", -1)
            val phase = Phase.from(item.optString("phase"))
            if (at <= 0 || day !in days.indices || slot !in 0..5 || phase == null) return@mapNotNull null
            if (days[day].slots.size != SlotKey.entries.size) return@mapNotNull null
            TimelineEntry(
                atMillis = at,
                dayIndex = day,
                slotIndex = slot,
                tomorrow = item.optBoolean("tomorrow"),
                phase = phase,
                kerahat = parseKerahat(item.optJSONObject("kerahat")),
            )
        }.sortedBy { it.atMillis }
    }

    private fun parseKerahat(json: JSONObject?): KerahatWindow? {
        if (json == null) return null
        val active = when (json.optString("state")) {
            "active" -> true
            "approaching" -> false
            else -> return null
        }
        val start = json.optLong("start", -1)
        val end = json.optLong("end", -1)
        if (start <= 0 || end <= start) return null
        return KerahatWindow(active, start, end)
    }

    private fun JSONObject.optNullableString(key: String): String? =
        if (!has(key) || isNull(key)) null else optString(key).takeIf { it.isNotBlank() }
}
