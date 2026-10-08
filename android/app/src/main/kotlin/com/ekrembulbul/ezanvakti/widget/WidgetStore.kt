package com.ekrembulbul.ezanvakti.widget

import android.content.Context

/** Dart'ın `home_widget` üzerinden yazdığı depo ve widget başına hizalama.
 *  Anahtarlar Dart `HomeWidgetPublisher` ile birebir aynı. */
object WidgetStore {
    /** `home_widget` paketinin SharedPreferences adı. */
    private const val PREFS = "HomeWidgetPreferences"
    private const val KEY_SNAPSHOT = "ezanvakti_snapshot"
    private const val KEY_APPEARANCE = "ezanvakti_appearance"
    private const val KEY_TIME_FORMAT = "ezanvakti_time_format"
    private const val KEY_NEXT_PRAYER = "ezanvakti_next_prayer_notification"

    private const val ALIGN_PREFS = "ezanvakti_widget_alignment"

    const val ALIGN_START = 0
    const val ALIGN_CENTER = 1
    const val ALIGN_END = 2

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun snapshotJson(context: Context): String? = prefs(context).getString(KEY_SNAPSHOT, null)
    fun appearanceJson(context: Context): String? = prefs(context).getString(KEY_APPEARANCE, null)
    fun timeFormat(context: Context): String? = prefs(context).getString(KEY_TIME_FORMAT, null)

    /** Uygulama henüz yazmadıysa açık (ayarın varsayılanı). */
    fun notificationEnabled(context: Context): Boolean =
        prefs(context).getString(KEY_NEXT_PRAYER, null) != "false"

    fun alignment(context: Context, widgetId: Int): Int =
        context.getSharedPreferences(ALIGN_PREFS, Context.MODE_PRIVATE)
            .getInt("align_$widgetId", ALIGN_CENTER)
            .takeIf { it in ALIGN_START..ALIGN_END } ?: ALIGN_CENTER

    fun setAlignment(context: Context, widgetId: Int, value: Int) {
        context.getSharedPreferences(ALIGN_PREFS, Context.MODE_PRIVATE).edit()
            .putInt("align_$widgetId", value.coerceIn(ALIGN_START, ALIGN_END)).apply()
    }

    fun removeAlignment(context: Context, widgetId: Int) {
        context.getSharedPreferences(ALIGN_PREFS, Context.MODE_PRIVATE).edit()
            .remove("align_$widgetId").apply()
    }
}
