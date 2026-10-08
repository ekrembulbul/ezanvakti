package com.ekrembulbul.ezanvakti

import java.util.Calendar
import java.util.TimeZone

/** Saat dilimi değişince sabit saatli alarm kaydını yeni dilimde aynı duvar
 *  saatine taşır. Vakte bağlı kayıtlar ilçenin mutlak vaktine, nöbetçiler
 *  görev zincirine bağlıdır; ikisi de aynen döner. `null` = kayıt geçmişte
 *  kaldı, iptal edilmeli. */
object AlarmTimeShift {
    fun shift(args: AlarmArgs, from: TimeZone, to: TimeZone, now: Long): AlarmArgs? {
        val hour = args.repeatHour ?: return args
        if (args.isWatchdog || from.id == to.id) return args
        if (args.repeatWeekdays.isNotEmpty()) return AlarmRepeats.next(args, now, to) ?: args
        val old = Calendar.getInstance(from).apply { timeInMillis = args.timeMillis }
        val moved = Calendar.getInstance(to).apply {
            clear()
            set(
                old.get(Calendar.YEAR), old.get(Calendar.MONTH), old.get(Calendar.DAY_OF_MONTH),
                hour, args.repeatMinute ?: 0, 0,
            )
        }
        return if (moved.timeInMillis > now) args.copy(timeMillis = moved.timeInMillis) else null
    }
}
