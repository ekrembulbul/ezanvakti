package com.ekrembulbul.ezanvakti

import android.content.Intent
import org.json.JSONObject
import org.json.JSONArray
import java.util.logging.Logger

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
    val theme: AlarmTheme = AlarmTheme.FALLBACK,
    val alarmId: String = id,
    val missionEnabled: Boolean = false,
    val mission: String = "none",
    val missionLevel: Int = 1,
    val maxSnoozes: Int? = null,
    val graceSeconds: Int = 30,
    val maxRearms: Int = 40,
    val chainDurationMillis: Long = 3_600_000,
    val missionTimeoutSeconds: Int = 90,
    val originalFireAtMillis: Long? = null,
    val repeatWeekdays: List<Int> = emptyList(),
    val repeatHour: Int? = null,
    val repeatMinute: Int? = null,
    val templateWeekdays: List<Int>? = null,
) {
    val opensApp get() = missionEnabled || snoozeEnabled
    val isWatchdog get() = originalFireAtMillis != null
    val isValid get() = id.isNotBlank() && id.length <= 256 && alarmId.isNotBlank() && alarmId.length <= 256 &&
        timeMillis in 1..8_640_000_000_000_000L &&
        snoozeMinutes in 1..1440 && graceSeconds in 1..3600 && maxRearms in 1..1000 &&
        chainDurationMillis in 1..(7 * 86_400_000L) &&
        (maxSnoozes == null || maxSnoozes in 0..1000) &&
        (originalFireAtMillis == null || originalFireAtMillis in 1..timeMillis) &&
        (!missionEnabled || missionTimeoutSeconds in 1..3600) && repeatWeekdays.all { it in 1..7 } &&
        (templateWeekdays?.all { it in 1..7 } ?: true) &&
        (repeatHour == null || repeatHour in 0..23) && (repeatMinute == null || repeatMinute in 0..59)

    fun writeTo(intent: Intent) {
        intent.putExtra(PAYLOAD, toJson())
    }

    fun toJson(): String = JSONObject().apply {
        put("id", id)
        put("timeMillis", timeMillis)
        put("label", label)
        put("soundId", soundId)
        put("vibrate", vibrate)
        put("snoozeEnabled", snoozeEnabled)
        put("snoozeMinutes", snoozeMinutes)
        put("theme", theme.toJson())
        put("alarmId", alarmId)
        put("missionEnabled", missionEnabled)
        put("mission", mission)
        put("missionLevel", missionLevel)
        put("maxSnoozes", maxSnoozes ?: JSONObject.NULL)
        put("graceSeconds", graceSeconds)
        put("maxRearms", maxRearms)
        put("chainDurationMillis", chainDurationMillis)
        put("missionTimeoutSeconds", missionTimeoutSeconds)
        put("originalFireAtMillis", originalFireAtMillis ?: JSONObject.NULL)
        put("repeatWeekdays", JSONArray(repeatWeekdays))
        put("repeatHour", repeatHour ?: JSONObject.NULL)
        put("repeatMinute", repeatMinute ?: JSONObject.NULL)
        put("templateWeekdays", templateWeekdays?.let { JSONArray(it) } ?: JSONObject.NULL)
    }.toString()

    companion object {
        private const val PAYLOAD = "alarmPayloadV2"

        fun fromMap(values: Map<*, *>): AlarmArgs {
            val chain = values["chainConfig"] as? Map<*, *> ?: emptyMap<Any, Any>()
            val id = values["id"] as? String ?: ""
            return AlarmArgs(
                id = id, timeMillis = (values["timeMillis"] as? Number)?.toLong() ?: 0,
                label = values["label"] as? String ?: "",
                soundId = values["soundId"] as? String ?: "default",
                vibrate = values["vibrate"] as? Boolean ?: true,
                snoozeEnabled = values["snoozeEnabled"] as? Boolean ?: false,
                snoozeMinutes = (values["snoozeMinutes"] as? Number)?.toInt() ?: 5,
                theme = AlarmTheme.fromMap(values["theme"] as? Map<*, *>),
                alarmId = chain["alarmId"] as? String ?: id,
                missionEnabled = values["missionEnabled"] as? Boolean ?: false,
                mission = values["mission"] as? String ?: "none",
                missionLevel = (values["missionLevel"] as? Number)?.toInt() ?: 1,
                maxSnoozes = (chain["maxSnoozes"] as? Number)?.toInt(),
                graceSeconds = (chain["graceSeconds"] as? Number)?.toInt() ?: 30,
                maxRearms = (chain["maxRearms"] as? Number)?.toInt() ?: 40,
                chainDurationMillis = (chain["chainDurationMillis"] as? Number)?.toLong() ?: 3_600_000,
                missionTimeoutSeconds = (chain["missionTimeoutSeconds"] as? Number)?.toInt() ?: 90,
                repeatWeekdays = (values["repeatWeekdays"] as? List<*>)
                    ?.map { (it as Number).toInt() } ?: emptyList(),
                repeatHour = (chain["repeatHour"] as? Number)?.toInt(),
                repeatMinute = (chain["repeatMinute"] as? Number)?.toInt(),
                templateWeekdays = (chain["templateWeekdays"] as? List<*>)?.map { (it as Number).toInt() },
            ).also { require(it.isValid) { "Invalid alarm arguments" } }
        }

        fun readFrom(intent: Intent): AlarmArgs {
            intent.getStringExtra(PAYLOAD)?.let { fromJson(it)?.let { args -> return args } }
            // PendingIntents created by older releases used flat extras.
            return AlarmArgs(
            id = intent.getStringExtra("id") ?: "",
            timeMillis = intent.getLongExtra("timeMillis", 0L),
            label = intent.getStringExtra("label") ?: "",
            soundId = intent.getStringExtra("soundId") ?: "adhan",
            vibrate = intent.getBooleanExtra("vibrate", true),
            snoozeEnabled = intent.getBooleanExtra("snoozeEnabled", true),
            snoozeMinutes = intent.getIntExtra("snoozeMinutes", 5),
            theme = AlarmTheme.fromJson(intent.getStringExtra("theme")),
            )
        }

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
                theme = AlarmTheme.fromJson(o.optString("theme")),
                alarmId = o.optString("alarmId", o.getString("id")),
                missionEnabled = o.optBoolean("missionEnabled", false),
                mission = o.optString("mission", "none"),
                missionLevel = o.optInt("missionLevel", 1),
                maxSnoozes = if (o.isNull("maxSnoozes")) null else o.getInt("maxSnoozes"),
                graceSeconds = o.optInt("graceSeconds", 30),
                maxRearms = o.optInt("maxRearms", 40),
                chainDurationMillis = o.optLong("chainDurationMillis", 3_600_000),
                missionTimeoutSeconds = o.optInt("missionTimeoutSeconds", 90),
                originalFireAtMillis = if (o.isNull("originalFireAtMillis")) null else o.getLong("originalFireAtMillis"),
                repeatWeekdays = o.optJSONArray("repeatWeekdays")?.let { array ->
                    (0 until array.length()).map { array.getInt(it) }
                } ?: emptyList(),
                repeatHour = if (o.isNull("repeatHour")) null else o.getInt("repeatHour"),
                repeatMinute = if (o.isNull("repeatMinute")) null else o.getInt("repeatMinute"),
                templateWeekdays = o.optJSONArray("templateWeekdays")?.let { array ->
                    (0 until array.length()).map { array.getInt(it) }
                },
            )
        } catch (error: Exception) {
            Logger.getLogger("EzanAlarm").warning("event=args_decode_failed type=" + error.javaClass.simpleName)
            null
        }
    }
}
