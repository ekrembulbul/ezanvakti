package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Alarm çalarken kilit ekranının üstünde açılan tam ekran çalar ekranı.
 *
 *  Renkler [AlarmTheme] ile Dart tarafından gelir; alarmın çalacağı anın
 *  dilimine göre uygulamanın dört paletinden biri kullanılır. */
class AlarmRingActivity : Activity() {
    private companion object {
        /** Flutter varlıkları APK içinde bu önek altında paketlenir. */
        const val MANROPE_ASSET = "flutter_assets/assets/fonts/Manrope-Variable.ttf"

        const val BUTTON_RADIUS_DP = 14f
        const val BADGE_RADIUS_DP = 20f

        /** Vurgu renginin yıkama alfaları; uygulamadaki `selectedControl` ile aynı. */
        const val BADGE_FILL_ALPHA = 0.14f
        const val BADGE_BORDER_ALPHA = 0.30f
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockscreen()
        setContentView(R.layout.activity_alarm_ring)

        val args = AlarmArgs.readFrom(intent)
        paint(args)
        bindActions(args)
    }

    // ── Görünüm ──────────────────────────────────────────────────────────────

    private fun paint(args: AlarmArgs) {
        val theme = args.theme
        val manrope = loadManrope()

        findViewById<View>(R.id.alarm_root).background = backgroundGradient(theme)

        findViewById<ImageView>(R.id.alarm_icon).setColorFilter(theme.accent)
        findViewById<FrameLayout>(R.id.alarm_badge).background = badgeShape(theme)

        text(R.id.alarm_kicker, manrope, 800, theme.textSecondary)

        val time = findViewById<TextView>(R.id.alarm_time)
        time.text = formatTime(args.timeMillis)
        time.visibility = if (time.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        text(R.id.alarm_time, manrope, 800, theme.accent)

        val title = findViewById<TextView>(R.id.alarm_title)
        title.text = args.label.ifBlank { getString(R.string.alarm_default_label) }
        text(R.id.alarm_title, manrope, 700, theme.textPrimary)

        val dismiss = findViewById<TextView>(R.id.alarm_dismiss)
        dismiss.background = filledButton(theme)
        // Dolgu vurgu rengi olduğu için üzerindeki yazı zeminin en koyu durağı.
        text(R.id.alarm_dismiss, manrope, 700, theme.backgroundStops.last())

        text(R.id.alarm_snooze, manrope, 700, theme.accent)
        findViewById<TextView>(R.id.alarm_snooze).background = outlinedButton(theme)
    }

    private fun text(viewId: Int, typeface: Typeface?, weight: Int, color: Int) {
        val view = findViewById<TextView>(viewId)
        view.setTextColor(color)
        if (typeface == null) return
        view.typeface = typeface
        // Değişken fontta kalınlık `wght` ekseninden seçilir; yalnızca bold
        // bayrağı vermek sentetik kalınlık üretir.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.fontVariationSettings = "'wght' $weight"
        }
    }

    /** Uygulamanın zemin gradyanı: üstten alta üç durak. */
    private fun backgroundGradient(theme: AlarmTheme): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            theme.backgroundStops.toIntArray(),
        )
    }

    private fun badgeShape(theme: AlarmTheme): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(BADGE_RADIUS_DP)
            setColor(theme.accent.withAlpha(BADGE_FILL_ALPHA))
            setStroke(dp(1f).toInt(), theme.accent.withAlpha(BADGE_BORDER_ALPHA))
        }
    }

    private fun filledButton(theme: AlarmTheme): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(BUTTON_RADIUS_DP)
            setColor(theme.accent)
        }
    }

    private fun outlinedButton(theme: AlarmTheme): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(BUTTON_RADIUS_DP)
            setColor(Color.TRANSPARENT)
            setStroke(dp(1.5f).toInt(), theme.accent.withAlpha(0.45f))
        }
    }

    /** Manrope, Flutter varlıklarıyla birlikte paketleniyor; ayrıca kopyalamak
     *  yerine oradan okunur. Bulunamazsa sistem fontuna düşülür. */
    private fun loadManrope(): Typeface? = try {
        Typeface.createFromAsset(assets, MANROPE_ASSET)
    } catch (_: Exception) {
        null
    }

    private fun formatTime(millis: Long): String {
        if (millis <= 0L) return ""
        return SimpleDateFormat("HH:mm", Locale("tr", "TR")).format(Date(millis))
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density

    private fun Int.withAlpha(alpha: Float): Int =
        Color.argb((alpha * 255).toInt(), Color.red(this), Color.green(this), Color.blue(this))

    // ── Davranış ─────────────────────────────────────────────────────────────

    private fun bindActions(args: AlarmArgs) {
        findViewById<TextView>(R.id.alarm_dismiss).setOnClickListener {
            sendToService(AlarmRingService.ACTION_STOP, args)
            finish()
        }

        val snooze = findViewById<TextView>(R.id.alarm_snooze)
        if (args.snoozeEnabled) {
            snooze.text = getString(R.string.alarm_snooze_minutes, args.snoozeMinutes)
            snooze.setOnClickListener {
                sendToService(AlarmRingService.ACTION_SNOOZE, args)
                finish()
            }
        } else {
            snooze.visibility = View.GONE
        }
    }

    private fun showOverLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

    private fun sendToService(action: String, args: AlarmArgs) {
        val i = Intent(this, AlarmRingService::class.java).apply {
            this.action = action
            args.writeTo(this)
        }
        startService(i)
    }

    // Geri tuşuyla alarm kapatılmasın; kapat/ertele butonları kullanılsın.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // yok say
    }
}
