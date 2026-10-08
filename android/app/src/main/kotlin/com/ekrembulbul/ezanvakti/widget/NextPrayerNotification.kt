package com.ekrembulbul.ezanvakti.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Typeface
import android.os.Build
import android.os.SystemClock
import android.text.SpannableString
import android.text.style.StyleSpan
import android.text.format.DateFormat
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.ekrembulbul.ezanvakti.MainActivity
import com.ekrembulbul.ezanvakti.R
import java.util.Locale
import kotlin.math.roundToInt

/** Bildirim çubuğundaki sabit "sıradaki vakit" satırı (spec K2–K5, D13).
 *
 *  Kapalıyken tek satır (vakit adı + saati, canlı geri sayım); açılınca kerahat
 *  kartı (yalnız kerahat penceresinde), cetvel ve altı vakit. Kerahat
 *  penceresinde başlıkta kelime ve kerahat sayacı, simge rengi turuncu/bordo.
 *  Zemin sistemin bildirim zeminidir; palet koyu/açıklığı her zaman cihazın
 *  gece modunu izler (uygulamanın tema ayarını değil). İçerik
 *  [NextPrayerContent]'te; burada yalnız `RemoteViews` ve bildirim kurulur. */
object NextPrayerNotification {
    private const val TAG = "EzanWidget"
    const val CHANNEL_ID = "ezan_vakti_next_prayer"
    const val NOTIFICATION_ID = 9930001
    private const val CONTENT_REQUEST = 9930001
    private const val DELETE_REQUEST = 9930002

    /** Kapalı gövde bazı sürümlerde 48 dp: satırdaki yazılar bu ölçeğin
     *  üstünde büyümez (30sp sayaç × 1.3 ≈ 39 dp, satır 48 dp'ye sığar). */
    private const val MAX_FONT_SCALE = 1.3f

    /** Cetvel bitmap'inin dış halkası için bildirim zeminine yakın renk. */
    private const val SURFACE_DARK = 0xFF2B2930.toInt()
    private const val SURFACE_LIGHT = 0xFFFFFBFE.toInt()

    /** API 34 öncesinde sistem bildirim metin renginin yaklaşığı (geçmiş
     *  vakitleri soldurmak için; RemoteViews'ta görünüm saydamlığı API 24'te
     *  uzaktan ayarlanamıyor). */
    private const val ON_SURFACE_DARK = 0xFFE6E1E5.toInt()
    private const val ON_SURFACE_LIGHT = 0xFF1D1B20.toInt()
    private const val PAST_ALPHA = 0.45f
    private const val NEXT_BG_ALPHA = 41 // ≈ 0.16 × 255

    /** Bildirim gövdesinin ekran genişliğinden düşülen yatay payı (dp):
     *  API 31+ çerçeve şablonu içerik başı 52 + sonu 16, gölge paneli kenarları
     *  2 × 16; öncesinde içerik 16 + 16 ve panel payı. Yaklaşıktır; cetvel
     *  bitmap'i `fitXY` ile gerçek genişliğe yayılır. */
    private const val INSET_DP_S = 100
    private const val INSET_DP_LEGACY = 48
    private const val MAX_SHADE_DP = 480
    private const val MIN_RULER_DP = 160
    private const val CLOCK_WIDTH_DP = 72f

    private val COLUMN_BG = intArrayOf(
        R.id.next_prayer_col_bg_0, R.id.next_prayer_col_bg_1, R.id.next_prayer_col_bg_2,
        R.id.next_prayer_col_bg_3, R.id.next_prayer_col_bg_4, R.id.next_prayer_col_bg_5,
    )
    private val COLUMN_NAME = intArrayOf(
        R.id.next_prayer_col_name_0, R.id.next_prayer_col_name_1, R.id.next_prayer_col_name_2,
        R.id.next_prayer_col_name_3, R.id.next_prayer_col_name_4, R.id.next_prayer_col_name_5,
    )
    private val COLUMN_TIME = intArrayOf(
        R.id.next_prayer_col_time_0, R.id.next_prayer_col_time_1, R.id.next_prayer_col_time_2,
        R.id.next_prayer_col_time_3, R.id.next_prayer_col_time_4, R.id.next_prayer_col_time_5,
    )

    /** Satırı kurar ya da günceller; gösterilecek bir şey yoksa kaldırır.
     *  Ayar kapalı, bildirim izni yok, veri yok ya da çizelge bitmiş (bayat). */
    fun update(context: Context) {
        val app = context.applicationContext
        if (!WidgetStore.notificationEnabled(app) || !NotificationManagerCompat.from(app).areNotificationsEnabled()) {
            cancel(app)
            return
        }
        val snapshot = (WidgetSnapshotParser.parse(WidgetStore.snapshotJson(app)) as? SnapshotResult.Ok)?.snapshot
        val now = System.currentTimeMillis()
        val state = snapshot?.let { WidgetTimeline.state(it, now) }
        if (snapshot == null || state == null || state.stale) {
            cancel(app)
            return
        }

        val systemDark = (app.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        // Bildirim zemini uygulamanın temasını değil sistemi izler: tema ayarı
        // "system"e çekilir, dilim/sabit palet tercihi korunur.
        val appearance = WidgetAppearance.parse(WidgetStore.appearanceJson(app)).copy(themeMode = "system")
        val palette = WidgetPalette.resolve(appearance, state.entry.phase, systemDark)
        val timePref = WidgetStore.timeFormat(app)
        val system24 = DateFormat.is24HourFormat(app)
        val content = NextPrayerContent.from(state, snapshot, palette, timePref, system24, Locale.getDefault(), now)

        ensureChannel(app)
        val builder = NotificationCompat.Builder(app, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsedViews(app, content, now))
            .setCustomBigContentView(
                expandedViews(app, content, palette, systemDark, WidgetTimeFormat.pattern(timePref, system24), now),
            )
            // Özel görünümü göstermeyen yüzeyler (ör. bazı kilit ekranları) için.
            .setContentTitle(content.nameText + " " + content.timeText)
            .setSubText(content.subText)
            .setColor(content.accentColor)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent(app))
            .setDeleteIntent(deleteIntent(app))
        val headerTarget = content.headerChronometerTarget
        if (headerTarget != null) {
            builder.setShowWhen(true)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setWhen(headerTarget)
        } else {
            builder.setShowWhen(false)
        }

        val manager = app.getSystemService(NotificationManager::class.java) ?: return
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (error: SecurityException) {
            // İzin denetimle notify arasında geri alındı: satır gösterilemez,
            // izin gelince sonraki tazelemede çıkar.
            Log.w(TAG, "event=next_prayer_denied type=" + error.javaClass.simpleName)
        }
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context.applicationContext).cancel(NOTIFICATION_ID)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        // Var olan kanalda yalnız ad güncellenir (dil değişimi); kullanıcının
        // kanal ayarlarına dokunulmaz.
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.next_prayer_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun collapsedViews(context: Context, content: NextPrayerContent, now: Long): RemoteViews =
        RemoteViews(context.packageName, R.layout.notification_next_prayer).also {
            bindRow(context, it, content, now)
        }

    private fun expandedViews(
        context: Context,
        content: NextPrayerContent,
        palette: Palette,
        systemDark: Boolean,
        clockPattern: String,
        now: Long,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_next_prayer_expanded)
        bindRow(context, views, content, now)
        bindCard(views, content.card, now)
        bindRuler(context, views, content, palette, systemDark, clockPattern)
        bindColumns(context, views, content, systemDark)
        return views
    }

    /** Kapalı ve açık halde ortak satır: vakit adı (vurgu; kerahatte bordo),
     *  saati, geri sayım (kerahatte bordo). */
    private fun bindRow(context: Context, views: RemoteViews, content: NextPrayerContent, now: Long) {
        views.setTextViewText(R.id.next_prayer_name, content.nameText)
        views.setTextColor(R.id.next_prayer_name, content.nameColor)
        views.setTextViewText(R.id.next_prayer_time, content.timeText)
        setCountdown(views, R.id.next_prayer_countdown, content.countdownTarget, now)
        content.countdownColor?.let { views.setTextColor(R.id.next_prayer_countdown, it) }

        val scale = context.resources.configuration.fontScale.coerceAtMost(MAX_FONT_SCALE)
        views.setTextViewTextSize(R.id.next_prayer_name, TypedValue.COMPLEX_UNIT_DIP, 13f * scale)
        views.setTextViewTextSize(R.id.next_prayer_time, TypedValue.COMPLEX_UNIT_DIP, 19f * scale)
        views.setTextViewTextSize(R.id.next_prayer_countdown, TypedValue.COMPLEX_UNIT_DIP, 30f * scale)
    }

    private fun bindCard(views: RemoteViews, card: NextPrayerContent.Card?, now: Long) {
        if (card == null) {
            views.setViewVisibility(R.id.next_prayer_card, View.GONE)
            return
        }
        views.setViewVisibility(R.id.next_prayer_card, View.VISIBLE)
        views.setInt(R.id.next_prayer_card_bg, "setColorFilter", card.surfaceColor)
        views.setTextViewText(R.id.next_prayer_card_word, card.word)
        views.setTextColor(R.id.next_prayer_card_word, card.textColor)
        views.setTextViewText(R.id.next_prayer_card_range, card.rangeText)
        views.setTextColor(R.id.next_prayer_card_range, card.rangeColor)
        views.setTextColor(R.id.next_prayer_card_countdown, card.textColor)
        setCountdown(views, R.id.next_prayer_card_countdown, card.targetMillis, now)
    }

    private fun bindRuler(
        context: Context,
        views: RemoteViews,
        content: NextPrayerContent,
        palette: Palette,
        systemDark: Boolean,
        clockPattern: String,
    ) {
        val density = context.resources.displayMetrics.density
        val widthPx = rulerWidthPx(context)
        val ruler = content.ruler
        val bitmap = RulerBitmap.draw(
            widthPx, density, ruler.parts, ruler.marks, ruler.nowFraction, palette,
            if (systemDark) SURFACE_DARK else SURFACE_LIGHT,
        )
        views.setImageViewBitmap(R.id.next_prayer_ruler, bitmap)

        val fraction = ruler.nowFraction
        if (fraction == null) {
            // Gösterilen gün yarın: nokta yok, etiket yerini korur (ritim bozulmasın).
            views.setViewVisibility(R.id.next_prayer_clock, View.INVISIBLE)
            return
        }
        views.setViewVisibility(R.id.next_prayer_clock, View.VISIBLE)
        views.setTextColor(R.id.next_prayer_clock, content.highlightColor)
        // Kullanıcının 12/24 tercihi sistemden bağımsız: iki biçim de aynı kalıp.
        views.setCharSequence(R.id.next_prayer_clock, "setFormat12Hour", clockPattern)
        views.setCharSequence(R.id.next_prayer_clock, "setFormat24Hour", clockPattern)
        val clockWidth = (CLOCK_WIDTH_DP * density).roundToInt()
        val dot = RulerBitmap.dotCenterPx(widthPx, density, fraction)
        val left = (dot - clockWidth / 2f).roundToInt().coerceIn(0, (widthPx - clockWidth).coerceAtLeast(0))
        views.setViewPadding(R.id.next_prayer_clock_box, left, 0, 0, 0)
    }

    private fun bindColumns(context: Context, views: RemoteViews, content: NextPrayerContent, systemDark: Boolean) {
        val faded = Palette.withAlpha(onSurface(context, systemDark), PAST_ALPHA)
        for (index in COLUMN_NAME.indices) {
            val column = content.columns.getOrNull(index)
            if (column == null) {
                views.setTextViewText(COLUMN_NAME[index], "")
                views.setTextViewText(COLUMN_TIME[index], "")
                views.setViewVisibility(COLUMN_BG[index], View.GONE)
                continue
            }
            views.setTextViewText(COLUMN_NAME[index], column.name)
            when (column.status) {
                NextPrayerContent.Status.NEXT -> {
                    views.setTextViewText(COLUMN_TIME[index], bold(column.timeText))
                    views.setTextColor(COLUMN_NAME[index], content.highlightColor)
                    views.setTextColor(COLUMN_TIME[index], content.highlightColor)
                    views.setViewVisibility(COLUMN_BG[index], View.VISIBLE)
                    views.setInt(COLUMN_BG[index], "setColorFilter", content.highlightColor)
                    views.setInt(COLUMN_BG[index], "setImageAlpha", NEXT_BG_ALPHA)
                }
                NextPrayerContent.Status.PAST -> {
                    views.setTextViewText(COLUMN_TIME[index], column.timeText)
                    views.setTextColor(COLUMN_NAME[index], faded)
                    views.setTextColor(COLUMN_TIME[index], faded)
                    views.setViewVisibility(COLUMN_BG[index], View.GONE)
                }
                // Gelecek vakitler: sistem bildirim renkleri (layout'taki stil).
                NextPrayerContent.Status.FUTURE -> {
                    views.setTextViewText(COLUMN_TIME[index], column.timeText)
                    views.setViewVisibility(COLUMN_BG[index], View.GONE)
                }
            }
        }
    }

    private fun setCountdown(views: RemoteViews, id: Int, targetMillis: Long, now: Long) {
        views.setChronometer(id, SystemClock.elapsedRealtime() + (targetMillis - now), null, true)
        views.setChronometerCountDown(id, true)
    }

    private fun bold(text: String): CharSequence =
        SpannableString(text).apply { setSpan(StyleSpan(Typeface.BOLD), 0, length, 0) }

    /** Sistem bildirim metninin rengi: API 34+ sistemin (dinamik) yüzey üstü
     *  rengi, öncesinde Material yaklaşığı. */
    private fun onSurface(context: Context, systemDark: Boolean): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            context.getColor(
                if (systemDark) android.R.color.system_on_surface_dark else android.R.color.system_on_surface_light,
            )
        } else if (systemDark) ON_SURFACE_DARK else ON_SURFACE_LIGHT

    /** Bildirim gövdesinin tahmini genişliği (px). Bildirimin gerçek genişliği
     *  uygulamaya bildirilmez; dikey ekran genişliğinden şablon payları düşülür. */
    private fun rulerWidthPx(context: Context): Int {
        val config = context.resources.configuration
        val screenDp = minOf(config.screenWidthDp, config.screenHeightDp).takeIf { it > 0 } ?: 360
        val inset = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) INSET_DP_S else INSET_DP_LEGACY
        val dp = (minOf(screenDp, MAX_SHADE_DP) - inset).coerceAtLeast(MIN_RULER_DP)
        return (dp * context.resources.displayMetrics.density).roundToInt()
    }

    private fun contentIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        CONTENT_REQUEST,
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun deleteIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        DELETE_REQUEST,
        Intent(context, NextPrayerDismissReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
