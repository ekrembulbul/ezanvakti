package com.ekrembulbul.ezanvakti.widget

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Sabit "sıradaki vakit" satırının saf içeriği: Android'e dokunmaz, JVM'de
 *  test edilir. [NextPrayerNotification] bunu `RemoteViews`'a ve bildirim
 *  başlığına döker; hesap yoktur, yalnız zaman çizelgesi girişinin sunumu. */
data class NextPrayerContent(
    /** Başlık satırındaki ek metin: normalde konum, kerahat penceresinde
     *  "Kerahate" / "Kerahat". */
    val subText: String?,
    /** Başlıktaki geri sayımın hedefi; yalnız kerahat penceresinde (yaklaşırken
     *  başlangıç, kerahatte bitiş). Yoksa başlıkta saat gösterilmez. */
    val headerChronometerTarget: Long?,
    /** `setColor`: normalde palet vurgusu, yaklaşırken turuncu, kerahatte bordo. */
    val accentColor: Int,
    /** Cetvel saat etiketi ve sıradaki sütunun rengi (palet vurgusu). */
    val highlightColor: Int,
    /** Satırdaki vakit adının rengi: palet vurgusu, kerahatte bordo (widget'la
     *  aynı kural, K6). Android 12+ kapalı bildirimde başlık satırı çizilmez;
     *  kerahat kapalıyken bu renkten anlaşılır. */
    val nameColor: Int,
    /** Büyük sayacın rengi; `null` ise sistemin bildirim metin rengi.
     *  Kerahatte bordo. */
    val countdownColor: Int?,
    /** "ÖĞLE" ya da "YARIN · İMSAK". */
    val nameText: String,
    val timeText: String,
    /** Sağdaki büyük sayacın hedefi: sıradaki vaktin anı. */
    val countdownTarget: Long,
    val card: Card?,
    val columns: List<Column>,
    val ruler: Ruler,
) {
    /** Kerahat penceresinin sunumu: açık haldeki kart ve Android 12+'da
     *  kapalı satırdaki çip aynı kelime, sayaç ve renkleri kullanır. */
    data class Card(
        val word: String,
        /** "12:47 – 12:57". */
        val rangeText: String,
        val targetMillis: Long,
        val active: Boolean,
        val surfaceColor: Int,
        val textColor: Int,
        val rangeColor: Int,
    )

    enum class Status { PAST, NEXT, FUTURE }

    data class Column(val name: String, val timeText: String, val status: Status)

    /** [RulerBitmap.draw] girdileri; [nowFraction] `null` ise (gösterilen gün
     *  bugün değil) nokta ve saat etiketi gizlenir. */
    data class Ruler(val parts: List<RulerPart>, val marks: List<Float>, val nowFraction: Float?)

    companion object {
        private const val RANGE_ALPHA = 0.75f

        fun from(
            state: WidgetState,
            snapshot: WidgetSnapshot,
            palette: Palette,
            timePref: String?,
            system24: Boolean,
            locale: Locale,
            now: Long,
            zone: TimeZone = TimeZone.getDefault(),
        ): NextPrayerContent {
            val labels = snapshot.labels
            val kerahat = state.entry.kerahat
            fun time(millis: Long) = WidgetTimeFormat.format(millis, timePref, system24, locale, zone)

            val name = state.next.name.uppercase(locale)
            val nameText = if (state.entry.tomorrow) labels.tomorrow.uppercase(locale) + " · " + name else name

            val card = kerahat?.let { window ->
                val textColor = if (window.active) palette.kerahatText else palette.soonText
                Card(
                    word = if (window.active) labels.kerahat else labels.kerahatSoon,
                    rangeText = time(window.startMillis) + " – " + time(window.endMillis),
                    targetMillis = window.targetMillis,
                    active = window.active,
                    surfaceColor = if (window.active) palette.kerahatSurface else palette.soonSurface,
                    textColor = textColor,
                    rangeColor = Palette.withAlpha(textColor, RANGE_ALPHA),
                )
            }

            val columnFormat = columnFormat(timePref, system24, locale, zone)
            val columns = state.day.slots.mapIndexed { index, slot ->
                Column(
                    name = slot.name,
                    timeText = columnFormat.format(Date(slot.epochMillis)),
                    status = when {
                        index < state.entry.slotIndex -> Status.PAST
                        index == state.entry.slotIndex -> Status.NEXT
                        else -> Status.FUTURE
                    },
                )
            }

            return NextPrayerContent(
                subText = when {
                    kerahat == null -> snapshot.locationLabel.takeIf { it.isNotBlank() }
                    kerahat.active -> labels.kerahat
                    else -> labels.kerahatSoon
                },
                headerChronometerTarget = kerahat?.targetMillis,
                accentColor = when {
                    kerahat == null -> palette.accent
                    kerahat.active -> palette.kerahatLine
                    else -> palette.soonLine
                },
                highlightColor = palette.accent,
                nameColor = if (kerahat?.active == true) palette.kerahatText else palette.accent,
                countdownColor = if (kerahat?.active == true) palette.kerahatText else null,
                nameText = nameText,
                timeText = time(state.next.epochMillis),
                countdownTarget = state.next.epochMillis,
                card = card,
                columns = columns,
                ruler = Ruler(
                    parts = state.day.ruler,
                    marks = state.day.marks,
                    nowFraction = WidgetTimeline.nowFraction(state.day, now, zone),
                ),
            )
        }

        /** Altı sütun dar: 12 saat biçiminde ÖÖ/ÖS işareti atılır ("12:57 PM"
         *  sütuna sığmaz; sıra zaten sabahı/akşamı belli eder). */
        private fun columnFormat(timePref: String?, system24: Boolean, locale: Locale, zone: TimeZone) =
            SimpleDateFormat(WidgetTimeFormat.pattern(timePref, system24).replace("a", "").trim(), locale)
                .apply { timeZone = zone }
    }
}
