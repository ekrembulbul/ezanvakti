package com.ekrembulbul.ezanvakti

import java.util.Calendar
import java.util.TimeZone

object AlarmRepeats {
    fun next(args: AlarmArgs, after: Long, zone: TimeZone = TimeZone.getDefault()): AlarmArgs? {
        if (args.repeatWeekdays.isEmpty() || args.isWatchdog) return null
        val original = Calendar.getInstance(zone).apply { timeInMillis = args.timeMillis }
        val hour = args.repeatHour ?: original.get(Calendar.HOUR_OF_DAY)
        val minute = args.repeatMinute ?: original.get(Calendar.MINUTE)
        val base = Calendar.getInstance(zone).apply { timeInMillis = after }
        for (offset in 0..7) {
            val day = (base.clone() as Calendar).apply {
                add(Calendar.DAY_OF_MONTH, offset)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val isoDay = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            if (day.timeInMillis > after && isoDay in args.repeatWeekdays) {
                return args.copy(timeMillis = day.timeInMillis, repeatHour = hour, repeatMinute = minute)
            }
        }
        return null
    }
}
