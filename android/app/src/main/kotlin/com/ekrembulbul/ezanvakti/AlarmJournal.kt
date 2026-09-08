package com.ekrembulbul.ezanvakti

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/** Local diagnostics deliberately omit labels, QR data and sound file paths. */
class AlarmJournal(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences("ezanvakti_alarm_journal_v1", Context.MODE_PRIVATE)

    fun record(operation: String, args: AlarmArgs? = null, id: String? = null,
        result: String = "ok", error: Exception? = null) {
        val now = System.currentTimeMillis()
        try {
            val previous = JSONArray(preferences.getString("entries", "[]"))
            val entries = JSONArray()
            val start = maxOf(0, previous.length() - 2047)
            for (index in start until previous.length()) {
                val entry = previous.getJSONObject(index)
                if (entry.optLong("timeMillis") >= now - 7 * 86_400_000L) entries.put(entry)
            }
            entries.put(JSONObject().apply {
                put("timeMillis", now)
                put("operation", operation)
                put("scheduleId", args?.id ?: id ?: JSONObject.NULL)
                put("alarmId", args?.alarmId ?: JSONObject.NULL)
                put("expectedMillis", args?.timeMillis ?: JSONObject.NULL)
                put("originalFireMillis", args?.originalFireAtMillis ?: JSONObject.NULL)
                put("result", result)
                put("errorCode", error?.javaClass?.name ?: JSONObject.NULL)
            })
            if (!preferences.edit().putString("entries", entries.toString()).commit()) {
                Log.e("EzanAlarm", "event=journal_write_failed")
            }
        } catch (failure: Exception) {
            Log.e("EzanAlarm", "event=journal_failed type=" + failure.javaClass.simpleName)
        }
    }
}
