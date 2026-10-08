package com.ekrembulbul.ezanvakti

import kotlin.math.abs

/** Pusula hesapları; sensörden bağımsız, birim testli. */
object HeadingMath {
    // SensorManager.SENSOR_STATUS_* ile aynı değerler; testte Android
    // sınıfı yüklemeden kullanılsın diye burada.
    const val STATUS_UNRELIABLE = 0
    const val STATUS_LOW = 1
    const val STATUS_MEDIUM = 2
    const val STATUS_HIGH = 3

    fun normalize(degrees: Double): Double {
        val r = degrees % 360.0
        return if (r < 0) r + 360.0 else r
    }

    /** Manyetik yön + manyetik sapma = gerçek (coğrafi) yön. */
    fun trueHeading(magnetic: Double, declination: Double) = normalize(magnetic + declination)

    /** Derece cinsinden sapma payı; -1 = güvenilmez (arayüz kalibrasyon ister). */
    fun accuracyDegrees(estimateRadians: Float?, status: Int): Double {
        if (status <= STATUS_UNRELIABLE) return -1.0
        if (estimateRadians != null && estimateRadians >= 0f) return Math.toDegrees(estimateRadians.toDouble())
        return when (status) {
            STATUS_HIGH -> 10.0
            STATUS_MEDIUM -> 20.0
            else -> 40.0
        }
    }

    /** 1°'den küçük değişim ibreyi titretiyor (iOS'taki headingFilter = 1). */
    fun shouldEmit(previous: Double?, next: Double, threshold: Double = 1.0): Boolean {
        if (previous == null) return true
        val diff = abs(normalize(next - previous + 180.0) - 180.0)
        return diff >= threshold
    }
}
