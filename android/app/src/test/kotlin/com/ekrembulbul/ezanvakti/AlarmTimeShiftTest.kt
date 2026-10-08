package com.ekrembulbul.ezanvakti

import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class AlarmTimeShiftTest {
    private val istanbul = TimeZone.getTimeZone("Europe/Istanbul")
    private val berlin = TimeZone.getTimeZone("Europe/Berlin")

    private fun at(zone: String, day: Int, hour: Int, minute: Int = 0): Long =
        ZonedDateTime.of(2026, 10, day, hour, minute, 0, 0, ZoneId.of(zone)).toInstant().toEpochMilli()

    private val now = at("Europe/Istanbul", 10, 12)

    private fun fixed(time: Long, weekdays: List<Int> = emptyList(), hour: Int = 6, minute: Int = 0) =
        AlarmArgs("f", time, "", "default", vibrate = true, snoozeEnabled = true, snoozeMinutes = 5,
            repeatWeekdays = weekdays, repeatHour = hour, repeatMinute = minute)

    @Test fun datedFixedKeepsWallClockInNewZone() {
        val moved = AlarmTimeShift.shift(fixed(at("Europe/Istanbul", 11, 6)), istanbul, berlin, now)!!
        assertEquals(at("Europe/Berlin", 11, 6), moved.timeMillis)
    }

    @Test fun weeklyFixedMovesToNextWallClockOccurrence() {
        val weekly = fixed(at("Europe/Istanbul", 11, 6), (1..7).toList())
        val moved = AlarmTimeShift.shift(weekly, istanbul, berlin, now)!!
        assertEquals(at("Europe/Berlin", 11, 6), moved.timeMillis)
    }

    @Test fun sameZoneIsUntouched() {
        val args = fixed(at("Europe/Istanbul", 11, 6))
        assertSame(args, AlarmTimeShift.shift(args, istanbul, istanbul, now))
    }

    @Test fun anchoredAndWatchdogAreUntouched() {
        val anchored = fixed(at("Europe/Istanbul", 11, 5, 12)).copy(repeatHour = null, repeatMinute = null)
        assertSame(anchored, AlarmTimeShift.shift(anchored, istanbul, berlin, now))
        val watchdog = fixed(at("Europe/Istanbul", 11, 6)).copy(originalFireAtMillis = at("Europe/Istanbul", 11, 5))
        assertSame(watchdog, AlarmTimeShift.shift(watchdog, istanbul, berlin, now))
    }

    @Test fun datedRecordThatFallsIntoPastIsDropped() {
        // İstanbul 12:30 → Berlin 12:30 (İstanbul 13:30): gelecekte, kalır.
        val soon = fixed(at("Europe/Istanbul", 10, 12, 30), hour = 12, minute = 30)
        assertNotNull(AlarmTimeShift.shift(soon, istanbul, berlin, now))
        // Berlin 12:30 → İstanbul 12:30 (Berlin 11:30): geçmişte, düşer.
        val berlinNow = at("Europe/Berlin", 10, 12)
        val berlinSoon = fixed(at("Europe/Berlin", 10, 12, 30), hour = 12, minute = 30)
        assertNull(AlarmTimeShift.shift(berlinSoon, berlin, istanbul, berlinNow))
    }
}
