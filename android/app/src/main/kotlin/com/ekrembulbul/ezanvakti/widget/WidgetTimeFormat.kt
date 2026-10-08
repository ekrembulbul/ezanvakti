package com.ekrembulbul.ezanvakti.widget

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Saatleri kullanıcının 12/24 tercihine göre biçimler (iOS `TimeFormatting`).
 *  Tercih değerleri Dart `TimeFormatPreference.storageValue` ile aynı. */
object WidgetTimeFormat {
    fun pattern(preference: String?, system24: Boolean): String = when (preference) {
        "h24" -> "HH:mm"
        "h12" -> "h:mm a"
        else -> if (system24) "HH:mm" else "h:mm a"
    }

    fun format(
        epochMillis: Long,
        preference: String?,
        system24: Boolean,
        locale: Locale,
        zone: TimeZone = TimeZone.getDefault(),
    ): String = SimpleDateFormat(pattern(preference, system24), locale)
        .apply { timeZone = zone }
        .format(Date(epochMillis))
}
