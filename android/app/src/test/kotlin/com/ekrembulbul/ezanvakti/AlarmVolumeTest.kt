package com.ekrembulbul.ezanvakti

import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmVolumeTest {
    @Test fun nullPercentKeepsCurrentLevel() {
        assertEquals(4, AlarmVolume.targetIndex(null, current = 4, min = 1, max = 7))
    }

    @Test fun percentScalesToStreamRange() {
        assertEquals(7, AlarmVolume.targetIndex(100, current = 2, min = 1, max = 7))
        assertEquals(4, AlarmVolume.targetIndex(50, current = 1, min = 0, max = 7))
    }

    @Test fun lowPercentNeverRoundsToSilence() {
        assertEquals(1, AlarmVolume.targetIndex(10, current = 5, min = 0, max = 7))
        assertEquals(2, AlarmVolume.targetIndex(10, current = 5, min = 2, max = 7))
    }
}
