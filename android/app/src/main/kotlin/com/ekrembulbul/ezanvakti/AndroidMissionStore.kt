package com.ekrembulbul.ezanvakti

import android.content.Context
import android.util.Log

class AndroidMissionStore(context: Context) : MissionStateStorage {
    private val preferences = context.applicationContext.getSharedPreferences("ezanvakti_missions_v2", Context.MODE_PRIVATE)

    override fun read(): MissionState {
        val raw = preferences.getString("state", null) ?: return MissionState()
        return try { MissionState.fromJson(raw) } catch (error: Exception) {
            Log.e("EzanAlarm", "event=mission_state_decode_failed type=" + error.javaClass.simpleName)
            throw IllegalStateException("Mission state is unreadable", error)
        }
    }

    override fun write(state: MissionState) {
        check(preferences.edit().putString("state", state.toJson()).commit()) {
            "Mission state could not be persisted"
        }
    }

    companion object {
        fun missions(context: Context) = AlarmMissions(AndroidMissionStore(context))
    }
}
