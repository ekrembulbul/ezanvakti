package com.ekrembulbul.ezanvakti

import android.content.Intent

/** Bir alarmın tüm bilgisini taşıyan veri sınıfı; Intent extra'larıyla aktarılır. */
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
    }
}
