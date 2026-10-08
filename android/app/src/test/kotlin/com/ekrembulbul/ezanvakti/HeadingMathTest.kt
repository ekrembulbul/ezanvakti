package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class HeadingMathTest {
    @Test fun normalizeWrapsIntoCircle() {
        assertEquals(350.0, HeadingMath.normalize(-10.0), 1e-9)
        assertEquals(10.0, HeadingMath.normalize(370.0), 1e-9)
        assertEquals(0.0, HeadingMath.normalize(360.0), 1e-9)
    }

    @Test fun trueHeadingAddsDeclination() {
        assertEquals(5.0, HeadingMath.trueHeading(355.0, 10.0), 1e-9)
        assertEquals(350.0, HeadingMath.trueHeading(5.0, -15.0), 1e-9)
    }

    @Test fun accuracyPrefersEstimateAndRejectsUnreliable() {
        assertEquals(Math.toDegrees(0.1), HeadingMath.accuracyDegrees(0.1f, HeadingMath.STATUS_HIGH), 1e-6)
        assertEquals(20.0, HeadingMath.accuracyDegrees(-1f, HeadingMath.STATUS_MEDIUM), 1e-9)
        assertEquals(40.0, HeadingMath.accuracyDegrees(null, HeadingMath.STATUS_LOW), 1e-9)
        assertEquals(-1.0, HeadingMath.accuracyDegrees(0.1f, HeadingMath.STATUS_UNRELIABLE), 1e-9)
    }

    @Test fun emitsOnlyForOneDegreeChangeAcrossNorth() {
        assertTrue(HeadingMath.shouldEmit(null, 10.0))
        assertFalse(HeadingMath.shouldEmit(359.6, 0.2))
        assertTrue(HeadingMath.shouldEmit(359.5, 0.6))
    }
}
