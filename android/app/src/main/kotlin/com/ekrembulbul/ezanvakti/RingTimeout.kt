package com.ekrembulbul.ezanvakti

/** Çalma süresi sınırının saf kuralları.
 *
 *  Süre dolunca servis önce mevcut erteleme geçişini dener, olmazsa
 *  kaydırarak durdurmayla aynı yolu izler; yeni bir durum yok. */
object RingTimeout {
    fun delayMillis(limitMinutes: Int?): Long? = limitMinutes?.let { it * 60_000L }

    /** "Kaçırılan alarm" bildirimi yalnız alarm bir daha çalmayacaksa. Görevli
     *  alarmda zincir sürüyorsa alarm `graceSeconds` sonra yeniden çalar
     *  (ADR 0001); "kaçırıldı" demek yanlış olur. */
    fun missedNotice(missionEnabled: Boolean, chainContinues: Boolean) =
        !missionEnabled || !chainContinues
}
