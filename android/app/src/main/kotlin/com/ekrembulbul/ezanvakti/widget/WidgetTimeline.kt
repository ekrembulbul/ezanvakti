package com.ekrembulbul.ezanvakti.widget

/** Bir an için çizilecek her şey: geçerli giriş, gösterilen gün ve sıradaki vakit. */
data class WidgetState(
    val entry: TimelineEntry,
    val day: WidgetDay,
    val next: WidgetSlot,
    /** Çizelge bitti (uygulama günlerdir açılmadı): son hal soluk çizilir. */
    val stale: Boolean,
)

/** Zaman çizelgesinden o anki girişi seçer. Kural Dart'ta; burada yalnız seçim. */
object WidgetTimeline {
    fun state(snapshot: WidgetSnapshot, now: Long): WidgetState? {
        val entries = snapshot.timeline
        if (entries.isEmpty()) return null
        // Saat geri alındıysa (ilk girişten önce) ilk giriş gösterilir.
        val index = entries.indexOfLast { it.atMillis <= now }.coerceAtLeast(0)
        val entry = entries[index]
        val day = snapshot.days.getOrNull(entry.dayIndex) ?: return null
        val next = day.slots.getOrNull(entry.slotIndex) ?: return null
        val stale = now >= next.epochMillis
        return WidgetState(entry, day, next, stale)
    }

    /** Görünümün değişeceği bir sonraki an: sonraki giriş, o yoksa son girişin
     *  vakti (çizelge orada biter, widget soluklaşır). Yoksa `null`. */
    fun nextBoundary(snapshot: WidgetSnapshot, now: Long): Long? {
        snapshot.timeline.firstOrNull { it.atMillis > now }?.let { return it.atMillis }
        val last = snapshot.timeline.lastOrNull() ?: return null
        val end = snapshot.days.getOrNull(last.dayIndex)?.slots?.getOrNull(last.slotIndex)?.epochMillis
        return end?.takeIf { it > now }
    }

    /** Cetvel noktasının gösterilen gün içindeki oranı (0..1). [now] o takvim
     *  gününde değilse `null`: Yatsı'dan sonra widget ertesi günü gösterir ve
     *  nokta çizilmez. Gün uzunluğu takvimden (yaz saati günleri 23/25 saat). */
    fun nowFraction(day: WidgetDay, now: Long, zone: java.util.TimeZone = java.util.TimeZone.getDefault()): Float? {
        val parts = day.date.split("-").mapNotNull { it.toIntOrNull() }
        if (parts.size != 3) return null
        val start = java.util.Calendar.getInstance(zone).apply {
            clear()
            set(parts[0], parts[1] - 1, parts[2], 0, 0, 0)
        }
        val end = (start.clone() as java.util.Calendar).apply { add(java.util.Calendar.DAY_OF_MONTH, 1) }
        val span = end.timeInMillis - start.timeInMillis
        if (span <= 0 || now < start.timeInMillis || now >= end.timeInMillis) return null
        return ((now - start.timeInMillis).toFloat() / span).coerceIn(0f, 1f)
    }
}
