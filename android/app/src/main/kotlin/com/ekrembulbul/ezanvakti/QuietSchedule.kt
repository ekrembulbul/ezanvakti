package com.ekrembulbul.ezanvakti

import org.json.JSONArray
import org.json.JSONObject

/** Telefonun Rahatsız Etme'de olacağı aralık: başlangıç dahil, bitiş hariç. */
data class QuietInterval(val startMillis: Long, val endMillis: Long)

/** Sessiz pencere planının saf kuralları (Dart planı hesaplar, burası uygular).
 *  Android sınıfı kullanmaz; JVM birim testinde koşar. */
object QuietSchedule {
    fun parse(raw: List<*>): List<QuietInterval> = raw.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        val start = (map["startMillis"] as? Number)?.toLong() ?: return@mapNotNull null
        val end = (map["endMillis"] as? Number)?.toLong() ?: return@mapNotNull null
        if (start <= 0 || end <= start) null else QuietInterval(start, end)
    }.sortedBy { it.startMillis }

    fun encode(intervals: List<QuietInterval>): String = JSONArray().apply {
        intervals.forEach { put(JSONObject().put("s", it.startMillis).put("e", it.endMillis)) }
    }.toString()

    fun decode(json: String?): List<QuietInterval> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map {
                val o = array.getJSONObject(it)
                QuietInterval(o.getLong("s"), o.getLong("e"))
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun isInside(intervals: List<QuietInterval>, now: Long) =
        intervals.any { now >= it.startMillis && now < it.endMillis }

    fun nextBoundary(intervals: List<QuietInterval>, now: Long): Long? =
        intervals.flatMap { listOf(it.startMillis, it.endMillis) }.filter { it > now }.minOrNull()

    fun prune(intervals: List<QuietInterval>, now: Long) = intervals.filter { it.endMillis > now }

    /** Sisteme yazılacak durum; `null` = yazma. Yalnız istenen durum son
     *  uygulanandan farklıysa yazılır: kullanıcının elle kapattığı DND
     *  uygulama açılınca yeniden açılmaz. */
    fun decide(desired: Boolean, applied: Boolean): Boolean? = if (desired == applied) null else desired
}
