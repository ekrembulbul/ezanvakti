package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class RingTimeoutTest {
    @Test fun missedNoticeOnlyWhenTheAlarmWillNotRingAgain() {
        assertTrue(RingTimeout.missedNotice(missionEnabled = false, chainContinues = false))
        assertFalse(RingTimeout.missedNotice(missionEnabled = true, chainContinues = true))
        assertTrue(RingTimeout.missedNotice(missionEnabled = true, chainContinues = false))
    }

    @Test fun delayIsMinutesInMillis() {
        assertEquals(600_000L, RingTimeout.delayMillis(10))
        assertNull(RingTimeout.delayMillis(null))
    }
}
