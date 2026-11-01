package com.ekrembulbul.ezanvakti.widget

import org.junit.Assert.*
import org.junit.Test

class StatusIconCountdownTest {
    private val target = 1_800_000_000_000L
    private val minute = 60_000L

    @Test fun outsideLastHourShowsMoon() {
        assertNull(StatusIconCountdown.minutesLeft(target, target - 60 * minute - 1))
        assertNull(StatusIconCountdown.minutesLeft(target, target))
        assertNull(StatusIconCountdown.minutesLeft(target, target + 1))
    }

    @Test fun minutesRoundUp() {
        assertEquals(60, StatusIconCountdown.minutesLeft(target, target - 60 * minute))
        assertEquals(45, StatusIconCountdown.minutesLeft(target, target - 44 * minute - 10_000))
        assertEquals(44, StatusIconCountdown.minutesLeft(target, target - 44 * minute))
        assertEquals(1, StatusIconCountdown.minutesLeft(target, target - 1))
    }

    @Test fun nextChangeBeforeWindowIsWindowStart() {
        assertEquals(target - 60 * minute, StatusIconCountdown.nextChange(target, target - 2 * 60 * minute))
    }

    @Test fun nextChangeInsideWindowIsWhenNumberDrops() {
        // 44:10 kala "45"; 44:00 kala "44" olur.
        assertEquals(target - 44 * minute, StatusIconCountdown.nextChange(target, target - 44 * minute - 10_000))
        // Tam 60:00 kala "60"; 59:00 kala "59".
        assertEquals(target - 59 * minute, StatusIconCountdown.nextChange(target, target - 60 * minute))
        // Son dakikada bir sonraki değişim vaktin kendisi (ikon aya döner).
        assertEquals(target, StatusIconCountdown.nextChange(target, target - 30_000))
    }

    @Test fun noChangeAfterTarget() {
        assertNull(StatusIconCountdown.nextChange(target, target))
    }
}
