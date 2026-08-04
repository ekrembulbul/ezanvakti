package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.ImageView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Alarm çalarken kilit ekranının üstünde açılan tam ekran çalar ekranı.
 *
 *  Renkler [AlarmTheme] ile Dart tarafından gelir: kullanıcının koyu/açık tema
 *  seçimi ve sabit palet tercihi korunur, "vakte göre renk" açıkken palet
 *  alarmın çalacağı anın dilimine göre seçilir. */
class AlarmRingActivity : Activity() {
    private companion object {
        /** Flutter varlıkları APK içinde bu önek altında paketlenir. */
        const val MANROPE_ASSET = "flutter_assets/assets/fonts/Manrope-Variable.ttf"

        const val SNOOZE_RADIUS_DP = 30f

        /** Açık zeminde koyu durum çubuğu simgeleri gerekir. */
        const val LIGHT_BACKGROUND_LUMINANCE = 0.5
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

        findViewById<View>(R.id.alarm_root).background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            theme.backgroundStops.toIntArray(),
        )
        applySystemBarContrast(theme)

        findViewById<ImageView>(R.id.alarm_icon).setColorFilter(theme.textSecondary)

        val title = findViewById<TextView>(R.id.alarm_title)
        title.text = args.label.ifBlank { getString(R.string.alarm_default_label) }
        style(title, manrope, 600, theme.textSecondary)

        val time = findViewById<TextView>(R.id.alarm_time)
        time.text = formatTime(args.timeMillis)
        time.visibility = if (time.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        style(time, manrope, 800, theme.textPrimary)

        // Etiket zaten uygulama adıysa aynı satırı iki kez yazma.
        val appName = findViewById<TextView>(R.id.alarm_app_name)
        appName.visibility = if (args.label.isBlank()) View.GONE else View.VISIBLE
        style(appName, manrope, 500, theme.textSecondary)

        val snooze = findViewById<TextView>(R.id.alarm_snooze)
        snooze.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(SNOOZE_RADIUS_DP)
            setColor(theme.accent)
        }
        // Dolgu vurgu rengi olduğu için üzerindeki yazı zeminin en koyu durağı.
        style(snooze, manrope, 700, theme.backgroundStops.last())

        findViewById<SlideToStopView>(R.id.alarm_dismiss).applyTheme(
            theme,
            manrope,
            getString(R.string.alarm_slide_to_stop),
        )
    }

    private fun style(view: TextView, typeface: Typeface?, weight: Int, color: Int) {
        view.setTextColor(color)
        if (typeface == null) return
        view.typeface = typeface
        // Değişken fontta kalınlık `wght` ekseninden seçilir; yalnızca bold
        // bayrağı vermek sentetik kalınlık üretir.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.fontVariationSettings = "'wght' $weight"
        }
    }

    /** Açık palette durum çubuğu simgeleri koyu olmalı, yoksa okunmuyor. */
    private fun applySystemBarContrast(theme: AlarmTheme) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        val top = theme.backgroundStops.first()
        val isLight = luminance(top) > LIGHT_BACKGROUND_LUMINANCE
        val mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
        window.insetsController?.setSystemBarsAppearance(if (isLight) mask else 0, mask)
    }

    private fun luminance(color: Int): Double {
        return (0.299 * Color.red(color) +
            0.587 * Color.green(color) +
            0.114 * Color.blue(color)) / 255.0
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

    // ── Davranış ─────────────────────────────────────────────────────────────

    private fun bindActions(args: AlarmArgs) {
        findViewById<SlideToStopView>(R.id.alarm_dismiss).onCompleted = {
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

    // Geri tuşuyla alarm kapatılmasın; ertele/kaydır kontrolleri kullanılsın.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // yok say
    }
}
