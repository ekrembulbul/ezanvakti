package com.ekrembulbul.ezanvakti

import android.content.Intent
import org.json.JSONObject

/** Bir alarmın tüm bilgisini taşıyan veri sınıfı; Intent extra'larıyla aktarılır.
 *  Cihaz yeniden başladığında Dart çalıştırmadan yeniden kurabilmek için
 *  SharedPreferences'a JSON olarak da yazılır. */
data class AlarmArgs(
    val id: String,
    val timeMillis: Long,
    val label: String,
    val soundId: String,
    val vibrate: Boolean,
    val snoozeEnabled: Boolean,
    val snoozeMinutes: Int,
) {
    fun writeTo(intent: Intent) {
        intent.putExtra("id", id)
        intent.putExtra("timeMillis", timeMillis)
        intent.putExtra("label", label)
        intent.putExtra("soundId", soundId)
        intent.putExtra("vibrate", vibrate)
        intent.putExtra("snoozeEnabled", snoozeEnabled)
        intent.putExtra("snoozeMinutes", snoozeMinutes)
    }

    fun toJson(): String = JSONObject().apply {
        put("id", id)
        put("timeMillis", timeMillis)
        put("label", label)
        put("soundId", soundId)
        put("vibrate", vibrate)
        put("snoozeEnabled", snoozeEnabled)
        put("snoozeMinutes", snoozeMinutes)
    }.toString()

    companion object {
        fun readFrom(intent: Intent): AlarmArgs = AlarmArgs(
            id = intent.getStringExtra("id") ?: "",
            timeMillis = intent.getLongExtra("timeMillis", 0L),
            label = intent.getStringExtra("label") ?: "",
            soundId = intent.getStringExtra("soundId") ?: "adhan",
            vibrate = intent.getBooleanExtra("vibrate", true),
            snoozeEnabled = intent.getBooleanExtra("snoozeEnabled", true),
            snoozeMinutes = intent.getIntExtra("snoozeMinutes", 5),
        )

        fun fromJson(json: String): AlarmArgs? = try {
            val o = JSONObject(json)
            AlarmArgs(
                id = o.getString("id"),
                timeMillis = o.getLong("timeMillis"),
                label = o.optString("label", ""),
                soundId = o.optString("soundId", "adhan"),
                vibrate = o.optBoolean("vibrate", true),
                snoozeEnabled = o.optBoolean("snoozeEnabled", true),
                snoozeMinutes = o.optInt("snoozeMinutes", 5),
            )
        } catch (_: Exception) {
            null
        }
    }
}
