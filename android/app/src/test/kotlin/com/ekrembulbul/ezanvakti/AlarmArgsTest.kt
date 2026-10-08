package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class AlarmArgsTest {
    private val base = AlarmArgs("a", 1_000, "", "default", vibrate = true, snoozeEnabled = true, snoozeMinutes = 5)

    @Test fun volumeAndRingLimitSurviveJson() {
        val decoded = AlarmArgs.fromJson(base.copy(volumePercent = 70, ringLimitMinutes = 10).toJson())!!
        assertEquals(70, decoded.volumePercent)
        assertEquals(10, decoded.ringLimitMinutes)
    }

    @Test fun recordsWrittenBeforeTheFieldsReadAsNull() {
        val legacy = org.json.JSONObject(base.toJson()).apply {
            remove("volumePercent")
            remove("ringLimitMinutes")
        }.toString()
        val decoded = AlarmArgs.fromJson(legacy)!!
        assertNull(decoded.volumePercent)
        assertNull(decoded.ringLimitMinutes)
    }

    @Test fun dartPlanKeysAreRead() {
        val args = AlarmArgs.fromMap(mapOf(
            "id" to "a", "timeMillis" to 1_000L, "snoozeMinutes" to 5,
            "volume" to 70, "ringLimitMinutes" to 10,
        ))
        assertEquals(70, args.volumePercent)
        assertEquals(10, args.ringLimitMinutes)
        val unlimited = AlarmArgs.fromMap(mapOf("id" to "a", "timeMillis" to 1_000L, "volume" to null, "ringLimitMinutes" to null))
        assertNull(unlimited.volumePercent)
        assertNull(unlimited.ringLimitMinutes)
    }

    @Test fun outOfRangeValuesAreInvalid() {
        assertFalse(base.copy(volumePercent = 5).isValid)
        assertFalse(base.copy(volumePercent = 101).isValid)
        assertFalse(base.copy(ringLimitMinutes = 0).isValid)
        assertTrue(base.copy(volumePercent = 100, ringLimitMinutes = 120).isValid)
    }
}
