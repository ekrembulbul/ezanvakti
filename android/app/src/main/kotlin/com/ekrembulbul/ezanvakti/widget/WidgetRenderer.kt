package com.ekrembulbul.ezanvakti.widget

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.SizeF
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.RemoteViews
import androidx.core.os.BundleCompat
import com.ekrembulbul.ezanvakti.MainActivity
import com.ekrembulbul.ezanvakti.R
import java.util.Locale
import java.util.TimeZone
import kotlin.math.roundToInt

// ── Saf sunum modeli (JVM testlerinde Android sınıfı yüklemeden çalışır) ─────

/** Bir an için widget'ta yazacak her şey; renkler paletten çözülmüş halde. */
data class WidgetViewModel(
    /** Küçükte üst satır: "konum · tarih"; çizelge bittiyse "Güncel değil". */
    val smallTop: String,
    /** Ortada üst satırın solu: konum; çizelge bittiyse "Güncel değil". */
    val mediumLocation: String,
    /** Ortada üst satırın sağı: "gün, tarih · hicri gün ay". Kerahat
     *  penceresinde (çip gösterilir) ya da hiçbir parça yoksa `null`. */
    val mediumDate: String?,
    /** Büyük harf vakit adı; ertesi günün vakti ise "YARIN · İMSAK". */
    val nameText: String,
    val timeText: String,
    val countdownTargetMillis: Long,
    /** Küçükte alt yuvanın iki satırı (gün adı, hicri); eksik olan atlanır. */
    val bottomLines: List<String>,
    val kerahat: WidgetViewModel.Kerahat?,
    val columns: List<WidgetViewModel.Column>,
    val nameColor: Int,
    val countdownColor: Int,
    val stale: Boolean,
    val ruler: List<RulerPart>,
    val marks: List<Float>,
    /** Cetvel noktasının oranı; gösterilen gün bugün değilse `null` (nokta ve
     *  saat etiketi gizlenir). */
    val nowFraction: Float?,
) {
    /** Orta boyda bir vakit sütununun durumu: geçen soluk, sıradaki vurgulu. */
    enum class ColumnState { PAST, NEXT, FUTURE }

    data class Column(val name: String, val time: String, val state: ColumnState)

    /** Kerahat penceresi: küçükte alt yuvadaki kart, ortada sağ üstteki çip.
     *  Yaklaşırken sayaç başlangıca, kerahatte bitişe sayar. */
    data class Kerahat(
        val word: String,
        /** "12:47 – 12:57"; saat biçimi kullanıcının tercihine göre. */
        val rangeText: String,
        val targetMillis: Long,
        val active: Boolean,
        val surface: Int,
        val text: Int,
    )

    companion object {
        fun from(
            state: WidgetState,
            snapshot: WidgetSnapshot,
            palette: Palette,
            timePref: String?,
            system24: Boolean,
            locale: Locale,
            now: Long,
            zone: TimeZone = TimeZone.getDefault(),
        ): WidgetViewModel {
            val day = state.day
            val labels = snapshot.labels
            fun time(millis: Long) = WidgetTimeFormat.format(millis, timePref, system24, locale, zone)

            val name = state.next.name.uppercase(locale)
            val nameText = if (state.entry.tomorrow) "${labels.tomorrow.uppercase(locale)} · $name" else name

            // Çizelge bittiyse pencerenin sayacı geçmişe sayardı: kart/çip gösterilmez.
            val kerahat = state.entry.kerahat?.takeUnless { state.stale }?.let { window ->
                Kerahat(
                    word = if (window.active) labels.kerahat else labels.kerahatSoon,
                    rangeText = "${time(window.startMillis)} – ${time(window.endMillis)}",
                    targetMillis = window.targetMillis,
                    active = window.active,
                    surface = if (window.active) palette.kerahatSurface else palette.soonSurface,
                    text = if (window.active) palette.kerahatText else palette.soonText,
                )
            }
            val inKerahat = kerahat?.active == true
            val location = snapshot.locationLabel.trim()

            return WidgetViewModel(
                smallTop = if (state.stale) labels.stale else join(" · ", location, day.dateLabel),
                mediumLocation = if (state.stale) labels.stale else location,
                mediumDate = if (kerahat != null) {
                    null
                } else {
                    join(" · ", join(", ", day.weekday, day.dateLabel), day.hijriShort).ifEmpty { null }
                },
                nameText = nameText,
                timeText = time(state.next.epochMillis),
                countdownTargetMillis = state.next.epochMillis,
                bottomLines = listOfNotNull(day.weekday, day.hijri ?: day.hijriShort),
                kerahat = kerahat,
                columns = day.slots.mapIndexed { index, slot ->
                    val columnState = when {
                        index < state.entry.slotIndex -> ColumnState.PAST
                        index == state.entry.slotIndex -> ColumnState.NEXT
                        else -> ColumnState.FUTURE
                    }
                    Column(slot.name, time(slot.epochMillis), columnState)
                },
                nameColor = if (inKerahat) palette.kerahatText else palette.accent,
                countdownColor = if (inKerahat) palette.kerahatText else palette.textPrimary,
                stale = state.stale,
                ruler = day.ruler,
                marks = day.marks,
                nowFraction = WidgetTimeline.nowFraction(day, now, zone),
            )
        }

        /** Boş ya da eksik parçaları atlayarak birleştirir. */
        private fun join(separator: String, vararg parts: String?): String =
            parts.mapNotNull { part -> part?.trim()?.takeIf { it.isNotEmpty() } }.joinToString(separator)
    }
}

// ── RemoteViews çizimi ────────────────────────────────────────────────────────

/** Küçük ve orta widget'ın `RemoteViews`'ini çizer (spec K6–K8, D8–D10, D15).
 *
 *  Sayaçlar `Chronometer` (geri sayım), cetvel saati `TextClock`: ikisi de
 *  sistem tarafından canlı akar, dakikalık güncelleme gerekmez. Zemin ve cetvel
 *  widget boyutunda bitmap olarak çizilir; Android 12+'da her gerçek boyut için
 *  ayrı çizim verilir (boyut eşlemeli `RemoteViews`), altında seçenek
 *  paketindeki min/max ölçülerden tek boyut seçilir. */
object WidgetRenderer {
    /** Bu genişlikten (dp) itibaren orta düzen (spec D10). */
    const val MEDIUM_MIN_WIDTH_DP = 250f

    private const val DEFAULT_SIZE_DP = 110f
    /** Boyut eşlemesinde en fazla bu kadar boyut çizilir: her biri iki bitmap
     *  taşır ve RemoteViews'in bitmap belleği sınırlı. */
    private const val MAX_SIZES = 4
    private const val CONTENT_PADDING_DP = 14f
    /** `widget_medium.xml` içindeki `TextClock` genişliği. */
    private const val RULER_LABEL_WIDTH_DP = 64f
    /** Android 12 öncesinde sistemin widget köşe yarıçapı yok. */
    private const val FALLBACK_RADIUS_DP = 16f
    /** Bu yükseklikten (dp) kısa küçük widget'ta sayaç küçülür. */
    private const val SMALL_COMPACT_HEIGHT_DP = 150f
    private const val SMALL_COMPACT_COUNTDOWN_SP = 26f
    /** Orta düzen bu yüksekliklerin altında önce sütunları, sonra cetveli
     *  gizler (taşan içerik altta kesilmesin). */
    private const val MEDIUM_COLUMNS_MIN_HEIGHT_DP = 158f
    private const val MEDIUM_RULER_MIN_HEIGHT_DP = 122f

    private const val STALE_ALPHA = 0.55f
    private const val PAST_ALPHA = 0.5f
    private const val NEXT_SURFACE_ALPHA = 0.16f
    private const val RANGE_TEXT_ALPHA = 0.75f

    private val COLUMN_BG = intArrayOf(
        R.id.widget_col_bg0, R.id.widget_col_bg1, R.id.widget_col_bg2,
        R.id.widget_col_bg3, R.id.widget_col_bg4, R.id.widget_col_bg5,
    )
    private val COLUMN_NAME = intArrayOf(
        R.id.widget_col_name0, R.id.widget_col_name1, R.id.widget_col_name2,
        R.id.widget_col_name3, R.id.widget_col_name4, R.id.widget_col_name5,
    )
    private val COLUMN_TIME = intArrayOf(
        R.id.widget_col_time0, R.id.widget_col_time1, R.id.widget_col_time2,
        R.id.widget_col_time3, R.id.widget_col_time4, R.id.widget_col_time5,
    )

    /** Bir tazelemede bütün widget'lar için bir kez okunan girdiler. */
    class Inputs(
        val result: SnapshotResult,
        val appearance: WidgetAppearance,
        val timePref: String?,
        val system24: Boolean,
        val systemDark: Boolean,
        val locale: Locale,
        val zone: TimeZone,
        val density: Float,
    ) {
        companion object {
            fun load(context: Context): Inputs {
                val night = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                return Inputs(
                    result = WidgetSnapshotParser.parse(WidgetStore.snapshotJson(context)),
                    appearance = WidgetAppearance.parse(WidgetStore.appearanceJson(context)),
                    timePref = WidgetStore.timeFormat(context),
                    system24 = android.text.format.DateFormat.is24HourFormat(context),
                    systemDark = night == Configuration.UI_MODE_NIGHT_YES,
                    locale = Locale.getDefault(),
                    zone = TimeZone.getDefault(),
                    density = context.resources.displayMetrics.density,
                )
            }
        }
    }

    /** Widget'ın o anki görünümü; Android 12+'da her gerçek boyut için ayrı. */
    fun views(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        now: Long,
        inputs: Inputs = Inputs.load(context),
    ): RemoteViews {
        val options = manager.getAppWidgetOptions(widgetId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = BundleCompat.getParcelableArrayList(
                options, AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java,
            )?.distinct()?.take(MAX_SIZES)
            if (!sizes.isNullOrEmpty()) {
                return RemoteViews(sizes.associateWith { render(context, widgetId, it, now, inputs) })
            }
        }
        return render(context, widgetId, fallbackSize(context, options), now, inputs)
    }

    /** Tek boyut için çizim: küçük, orta ya da "uygulamayı aç". */
    fun render(context: Context, widgetId: Int, sizeDp: SizeF, now: Long, inputs: Inputs): RemoteViews {
        val snapshot = (inputs.result as? SnapshotResult.Ok)?.snapshot
        val state = snapshot?.let { WidgetTimeline.state(it, now) }
        if (snapshot == null || state == null) return message(context, sizeDp, inputs)
        val palette = WidgetPalette.resolve(inputs.appearance, state.entry.phase, inputs.systemDark)
        val model = WidgetViewModel.from(
            state, snapshot, palette, inputs.timePref, inputs.system24, inputs.locale, now, inputs.zone,
        )
        return if (sizeDp.width >= MEDIUM_MIN_WIDTH_DP) {
            medium(context, sizeDp, model, palette, now, inputs)
        } else {
            small(context, sizeDp, model, palette, now, inputs, WidgetStore.alignment(context, widgetId))
        }
    }

    // ── Düzenler ─────────────────────────────────────────────────────────────

    // Hizalama etiketleri "Sola/Sağa yaslı": RTL'de de mutlak yön kasıtlı.
    @SuppressLint("RtlHardcoded")
    private fun small(
        context: Context,
        size: SizeF,
        model: WidgetViewModel,
        palette: Palette,
        now: Long,
        inputs: Inputs,
        alignment: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        val fade = if (model.stale) STALE_ALPHA else 1f
        background(views, context, size, palette, fade, inputs)

        val horizontal = when (alignment) {
            WidgetStore.ALIGN_START -> Gravity.LEFT
            WidgetStore.ALIGN_END -> Gravity.RIGHT
            else -> Gravity.CENTER_HORIZONTAL
        }
        views.setInt(R.id.widget_top_row, "setGravity", horizontal or Gravity.CENTER_VERTICAL)
        views.setInt(R.id.widget_mid, "setGravity", horizontal or Gravity.CENTER_VERTICAL)
        views.setInt(R.id.widget_info, "setGravity", horizontal or Gravity.BOTTOM)

        text(views, R.id.widget_top, model.smallTop, faded(palette.textSecondary, fade))
        text(views, R.id.widget_name, model.nameText, faded(model.nameColor, fade))
        text(views, R.id.widget_time, model.timeText, faded(palette.textPrimary, fade))
        countdown(views, R.id.widget_countdown, model.countdownTargetMillis, now, running = !model.stale)
        views.setTextColor(R.id.widget_countdown, faded(model.countdownColor, fade))
        if (size.height < SMALL_COMPACT_HEIGHT_DP) {
            views.setTextViewTextSize(R.id.widget_countdown, TypedValue.COMPLEX_UNIT_SP, SMALL_COMPACT_COUNTDOWN_SP)
        }

        val kerahat = model.kerahat
        if (kerahat == null) {
            views.setViewVisibility(R.id.widget_card, View.GONE)
            views.setViewVisibility(R.id.widget_info, View.VISIBLE)
            optionalText(views, R.id.widget_line1, model.bottomLines.getOrNull(0), faded(palette.textSecondary, fade))
            optionalText(views, R.id.widget_line2, model.bottomLines.getOrNull(1), faded(palette.textSecondary, fade))
        } else {
            views.setViewVisibility(R.id.widget_info, View.GONE)
            views.setViewVisibility(R.id.widget_card, View.VISIBLE)
            surface(views, R.id.widget_card_bg, kerahat.surface, fade)
            text(views, R.id.widget_card_word, kerahat.word, faded(kerahat.text, fade))
            text(views, R.id.widget_card_range, kerahat.rangeText, faded(kerahat.text, RANGE_TEXT_ALPHA * fade))
            countdown(views, R.id.widget_card_countdown, kerahat.targetMillis, now, running = true)
            views.setTextColor(R.id.widget_card_countdown, faded(kerahat.text, fade))
        }
        return views
    }

    private fun medium(
        context: Context,
        size: SizeF,
        model: WidgetViewModel,
        palette: Palette,
        now: Long,
        inputs: Inputs,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_medium)
        val fade = if (model.stale) STALE_ALPHA else 1f
        background(views, context, size, palette, fade, inputs)

        text(views, R.id.widget_location, model.mediumLocation, faded(palette.textSecondary, fade))
        optionalText(views, R.id.widget_date, model.mediumDate, faded(palette.textSecondary, fade))
        val kerahat = model.kerahat
        if (kerahat == null) {
            views.setViewVisibility(R.id.widget_chip, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_chip, View.VISIBLE)
            surface(views, R.id.widget_chip_bg, kerahat.surface, fade)
            text(views, R.id.widget_chip_word, kerahat.word, faded(kerahat.text, fade))
            countdown(views, R.id.widget_chip_countdown, kerahat.targetMillis, now, running = true)
            views.setTextColor(R.id.widget_chip_countdown, faded(kerahat.text, fade))
        }

        text(views, R.id.widget_name, model.nameText, faded(model.nameColor, fade))
        text(views, R.id.widget_time, model.timeText, faded(palette.textPrimary, fade))
        countdown(views, R.id.widget_countdown, model.countdownTargetMillis, now, running = !model.stale)
        views.setTextColor(R.id.widget_countdown, faded(model.countdownColor, fade))

        val showRuler = model.ruler.isNotEmpty() && size.height >= MEDIUM_RULER_MIN_HEIGHT_DP
        if (showRuler) ruler(views, size, model, palette, fade, inputs)
        else views.setViewVisibility(R.id.widget_ruler_block, View.GONE)

        if (size.height >= MEDIUM_COLUMNS_MIN_HEIGHT_DP) columns(views, model, palette, fade)
        else views.setViewVisibility(R.id.widget_columns, View.GONE)
        return views
    }

    private fun message(context: Context, size: SizeF, inputs: Inputs): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_message)
        val palette = WidgetPalette.resolve(inputs.appearance, Phase.FALLBACK, inputs.systemDark)
        background(views, context, size, palette, 1f, inputs)
        views.setTextColor(R.id.widget_message, palette.textPrimary)
        return views
    }

    // ── Parçalar ─────────────────────────────────────────────────────────────

    private fun background(
        views: RemoteViews,
        context: Context,
        size: SizeF,
        palette: Palette,
        fade: Float,
        inputs: Inputs,
    ) {
        val bitmap = BackgroundBitmap.draw(
            px(size.width, inputs.density), px(size.height, inputs.density), cornerRadiusPx(context), palette.stops,
        )
        views.setImageViewBitmap(R.id.widget_bg, bitmap)
        views.setInt(R.id.widget_bg, "setImageAlpha", alpha255(fade))
        views.setOnClickPendingIntent(android.R.id.background, openApp(context))
    }

    private fun ruler(
        views: RemoteViews,
        size: SizeF,
        model: WidgetViewModel,
        palette: Palette,
        fade: Float,
        inputs: Inputs,
    ) {
        val density = inputs.density
        val widthPx = px(size.width - 2 * CONTENT_PADDING_DP, density)
        // Noktanın dış halkası zeminin orta durağıyla boyanır (cetvel kartın ortasında).
        val ringColor = palette.stops.getOrElse(1) { palette.stops.firstOrNull() ?: 0 }
        val bitmap = RulerBitmap.draw(
            widthPx, density, model.ruler, model.marks, model.nowFraction, palette, ringColor,
        )
        views.setImageViewBitmap(R.id.widget_ruler, bitmap)
        views.setInt(R.id.widget_ruler, "setImageAlpha", alpha255(fade))

        val fraction = model.nowFraction
        if (fraction == null) {
            views.setViewVisibility(R.id.widget_ruler_clock, View.INVISIBLE)
            return
        }
        val pattern = WidgetTimeFormat.pattern(inputs.timePref, inputs.system24)
        views.setCharSequence(R.id.widget_ruler_clock, "setFormat12Hour", pattern)
        views.setCharSequence(R.id.widget_ruler_clock, "setFormat24Hour", pattern)
        views.setTextColor(R.id.widget_ruler_clock, faded(palette.accent, fade))
        // Etiket noktanın tam üstünde ortalanır; kenarlarda cetvelin içinde kalır.
        val labelPx = RULER_LABEL_WIDTH_DP * density
        val dot = RulerBitmap.dotCenterPx(widthPx, density, fraction)
        val left = (dot - labelPx / 2).coerceIn(0f, (widthPx - labelPx).coerceAtLeast(0f))
        views.setViewPadding(R.id.widget_ruler_label_row, left.roundToInt(), 0, 0, 0)
    }

    private fun columns(views: RemoteViews, model: WidgetViewModel, palette: Palette, fade: Float) {
        for (index in COLUMN_NAME.indices) {
            val column = model.columns.getOrNull(index)
            if (column == null) {
                views.setViewVisibility(COLUMN_NAME[index], View.INVISIBLE)
                views.setViewVisibility(COLUMN_TIME[index], View.INVISIBLE)
                continue
            }
            when (column.state) {
                WidgetViewModel.ColumnState.NEXT -> {
                    views.setViewVisibility(COLUMN_BG[index], View.VISIBLE)
                    surface(views, COLUMN_BG[index], palette.accent, NEXT_SURFACE_ALPHA * fade)
                    text(views, COLUMN_NAME[index], column.name, faded(palette.accent, fade))
                    views.setTextViewText(COLUMN_TIME[index], bold(column.time))
                    views.setTextColor(COLUMN_TIME[index], faded(palette.accent, fade))
                }
                WidgetViewModel.ColumnState.PAST, WidgetViewModel.ColumnState.FUTURE -> {
                    val alpha = if (column.state == WidgetViewModel.ColumnState.PAST) PAST_ALPHA * fade else fade
                    views.setViewVisibility(COLUMN_BG[index], View.GONE)
                    text(views, COLUMN_NAME[index], column.name, faded(palette.textSecondary, alpha))
                    text(views, COLUMN_TIME[index], column.time, faded(palette.textPrimary, alpha))
                }
            }
        }
    }

    /** Geri sayım: sistem saniyede bir kendisi çizer. Hedef geçtiyse (çizelge
     *  bitti ya da tazeleme gecikti) eksiye saymasın diye sıfırda durur. */
    private fun countdown(views: RemoteViews, id: Int, targetMillis: Long, now: Long, running: Boolean) {
        val remaining = targetMillis - now
        views.setChronometerCountDown(id, true)
        if (running && remaining > 0) {
            views.setChronometer(id, SystemClock.elapsedRealtime() + remaining, null, true)
        } else {
            views.setChronometer(id, SystemClock.elapsedRealtime(), null, false)
        }
    }

    /** Beyaz şekil drawable'ını verilen renge boyar; saydamlık ayrı uygulanır
     *  (renk filtresi SRC_ATOP, rengin kendi alfası zemine karışırdı). */
    private fun surface(views: RemoteViews, id: Int, color: Int, alpha: Float) {
        views.setInt(id, "setColorFilter", color or OPAQUE)
        views.setInt(id, "setImageAlpha", alpha255(alpha * ((color ushr 24) / 255f)))
    }

    private fun text(views: RemoteViews, id: Int, value: CharSequence, color: Int) {
        views.setTextViewText(id, value)
        views.setTextColor(id, color)
    }

    private fun optionalText(views: RemoteViews, id: Int, value: String?, color: Int) {
        if (value.isNullOrBlank()) {
            views.setViewVisibility(id, View.GONE)
        } else {
            views.setViewVisibility(id, View.VISIBLE)
            text(views, id, value, color)
        }
    }

    private fun bold(value: String): CharSequence = SpannableString(value).apply {
        setSpan(StyleSpan(Typeface.BOLD), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun cornerRadiusPx(context: Context): Float =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.resources.getDimension(android.R.dimen.system_app_widget_background_radius)
        } else {
            FALLBACK_RADIUS_DP * context.resources.displayMetrics.density
        }

    /** Android 12 öncesi: dikeyde en küçük genişlik × en büyük yükseklik,
     *  yatayda tersi (AppWidgetManager seçenek sözleşmesi). */
    private fun fallbackSize(context: Context, options: Bundle): SizeF {
        val portrait = context.resources.configuration.orientation != Configuration.ORIENTATION_LANDSCAPE
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val maxH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val width = (if (portrait) minW else maxW).takeIf { it > 0 } ?: maxOf(minW, maxW)
        val height = (if (portrait) maxH else minH).takeIf { it > 0 } ?: maxOf(minH, maxH)
        return SizeF(
            width.takeIf { it > 0 }?.toFloat() ?: DEFAULT_SIZE_DP,
            height.takeIf { it > 0 }?.toFloat() ?: DEFAULT_SIZE_DP,
        )
    }

    private const val OPAQUE = 0xFF000000.toInt()

    private fun px(dp: Float, density: Float): Int = (dp * density).roundToInt().coerceAtLeast(1)

    private fun alpha255(alpha: Float): Int = (alpha.coerceIn(0f, 1f) * 255).roundToInt()

    /** Rengin kendi alfasını [factor] ile çarpar (soluk/bayat çizim). RemoteViews'te
     *  `View.setAlpha` her sürümde uzaktan çağrılamadığı için soluklaştırma
     *  renklere işlenir. */
    private fun faded(color: Int, factor: Float): Int =
        if (factor >= 1f) color else Palette.withAlpha(color, ((color ushr 24) / 255f) * factor)
}
