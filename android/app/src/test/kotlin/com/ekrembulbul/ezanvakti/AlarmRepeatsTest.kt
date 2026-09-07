package com.ekrembulbul.ezanvakti

import java.time.ZonedDateTime
import java.time.ZoneId
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class AlarmRepeatsTest {
    private val zone = TimeZone.getTimeZone("Europe/Berlin")
    private fun at(day: Int, hour: Int, minute: Int = 0): Long =
        ZonedDateTime.of(2026, 3, day, hour, minute, 0, 0, ZoneId.of("Europe/Berlin")).toInstant().toEpochMilli()
    private fun alarm() = AlarmArgs("daily", at(28, 2, 30), "daily", "default", true, true, 5,
        repeatWeekdays = (1..7).toList(), repeatHour = 2, repeatMinute = 30)

    @Test fun weeklyRepeatContinuesAndDoesNotDriftAfterDst() {
        val dst = AlarmRepeats.next(alarm(), at(28, 2, 31), zone)!!
        assertEquals(at(29, 3, 30), dst.timeMillis)
        val next = AlarmRepeats.next(dst, at(29, 3, 31), zone)!!
        assertEquals(at(30, 2, 30), next.timeMillis)
    }

    @Test fun oneOffAndWatchdogNeverCreateWeeklyRepeats() {
        assertNull(AlarmRepeats.next(alarm().copy(repeatWeekdays = emptyList()), at(28, 3), zone))
        assertNull(AlarmRepeats.next(alarm().copy(originalFireAtMillis = at(28, 2, 30)), at(28, 3), zone))
    }
}
