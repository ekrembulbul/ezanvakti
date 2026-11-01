package com.ekrembulbul.ezanvakti.widget

/** Sabit satırın durum çubuğu ikonu vakte son bir saat kala hilalin içinde
 *  kalan dakikayı gösterir. Burada yalnız hangi sayının gösterileceği ve
 *  sayının ne zaman değişeceği hesaplanır; çizim [StatusIconBitmap]'te. */
object StatusIconCountdown {
    const val WINDOW_MILLIS = 60 * 60_000L
    private const val MINUTE_MILLIS = 60_000L

    /** Gösterilecek dakika (1..60), yukarı yuvarlanmış: 44:10 kala 45, son
     *  dakikada 1. Son bir saatin dışında ya da vakit geçtiyse `null` (ay). */
    fun minutesLeft(targetMillis: Long, now: Long): Int? {
        val left = targetMillis - now
        if (left <= 0 || left > WINDOW_MILLIS) return null
        return ((left + MINUTE_MILLIS - 1) / MINUTE_MILLIS).toInt()
    }

    /** İkonun değişeceği bir sonraki an: pencereden önce pencerenin başı,
     *  içinde sayının bir azalacağı an (son dakikada vaktin kendisi). Vakit
     *  geçtiyse `null`. */
    fun nextChange(targetMillis: Long, now: Long): Long? {
        val minutes = minutesLeft(targetMillis, now)
        if (minutes == null) {
            return if (targetMillis - now > WINDOW_MILLIS) targetMillis - WINDOW_MILLIS else null
        }
        return targetMillis - (minutes - 1) * MINUTE_MILLIS
    }
}
