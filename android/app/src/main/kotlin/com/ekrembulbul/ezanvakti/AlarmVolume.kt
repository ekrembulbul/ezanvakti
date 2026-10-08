package com.ekrembulbul.ezanvakti

/** Alarm akışının (STREAM_ALARM) hedef seviye indeksi. */
object AlarmVolume {
    /** Yüzde verilmemişse mevcut seviye korunur; verilmişse akış aralığına
     *  sıkıştırılır. En az 1: yuvarlama alarmı sessiz bırakmasın. */
    fun targetIndex(percent: Int?, current: Int, min: Int, max: Int): Int {
        if (percent == null || max <= 0) return current
        return Math.round(max * percent / 100.0).toInt().coerceIn(maxOf(min, 1), max)
    }
}
