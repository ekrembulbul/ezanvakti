package com.ekrembulbul.ezanvakti

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.AttributeSet
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView

/** Alarmı kapatmak için kaydırılan kontrol.
 *
 *  Tek dokunuşla kapatma, çalan bir alarmda kazayla tetiklenmeye çok açık;
 *  iOS'un kilit ekranındaki "slide to stop" davranışı örnek alındı. Erteleme
 *  düğmesi normal dokunuşla çalışır, kapatma bilinçli bir hareket ister. */
class SlideToStopView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : FrameLayout(context, attrs) {

    private companion object {
        const val THUMB_SIZE_DP = 52f
        const val THUMB_INSET_DP = 4f
        const val ICON_SIZE_DP = 26f
        const val TRACK_FILL_ALPHA = 0.12f
        const val TRACK_BORDER_ALPHA = 0.25f

        /** Bu orana ulaşan kaydırma bırakıldığında alarm kapanır. */
        const val COMPLETE_AT = 0.85f

        /** Etiket kaydırma başlar başlamaz sönsün. */
        const val LABEL_FADE_FACTOR = 2.0f

        const val SETTLE_DURATION_MS = 160L
    }

    private val label = TextView(context)
    private val thumb = ImageView(context)

    private var dragging = false
    private var downX = 0f
    private var thumbStartX = 0f
    private var completed = false

    /** Kaydırma tamamlandığında bir kez çağrılır. */
    var onCompleted: (() -> Unit)? = null

    init {
        label.gravity = Gravity.CENTER
        addView(
            label,
            LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT).apply {
                gravity = Gravity.CENTER
            },
        )

        thumb.scaleType = ImageView.ScaleType.FIT_CENTER
        thumb.setImageResource(R.drawable.ic_stop_square)
        thumb.setPadding(dp(THUMB_SIZE_DP - ICON_SIZE_DP).toInt() / 2)
        addView(
            thumb,
            LayoutParams(dp(THUMB_SIZE_DP).toInt(), dp(THUMB_SIZE_DP).toInt()).apply {
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                marginStart = dp(THUMB_INSET_DP).toInt()
            },
        )

        isClickable = true
    }

    fun applyTheme(theme: AlarmTheme, typeface: Typeface?, text: String) {
        background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(THUMB_SIZE_DP / 2 + THUMB_INSET_DP)
            setColor(theme.accent.withAlpha(TRACK_FILL_ALPHA))
            setStroke(dp(1f).toInt(), theme.accent.withAlpha(TRACK_BORDER_ALPHA))
        }

        label.text = text
        label.setTextColor(theme.textSecondary)
        label.textSize = 15f
        if (typeface != null) {
            label.typeface = typeface
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                label.fontVariationSettings = "'wght' 600"
            }
        }

        thumb.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(theme.accent)
        }
        thumb.setColorFilter(theme.backgroundStops.last())

        contentDescription = text
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (completed) return false

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // Yalnızca tokmaktan başlayan hareket sürüklemedir; yatağın
                // ortasına dokunmak alarmı kapatmasın.
                if (event.x > thumb.right + dp(THUMB_INSET_DP)) return false
                dragging = true
                downX = event.rawX
                thumbStartX = thumb.translationX
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                if (!dragging) return false
                setProgressX(thumbStartX + (event.rawX - downX))
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (!dragging) return false
                dragging = false
                if (progress() >= COMPLETE_AT) {
                    complete()
                } else {
                    thumb.animate().translationX(0f).setDuration(SETTLE_DURATION_MS).start()
                    label.animate().alpha(1f).setDuration(SETTLE_DURATION_MS).start()
                }
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    /** Ekran okuyucu kullanıcıları kaydıramaz; onlar için doğrudan etkinleştirme. */
    override fun performClick(): Boolean {
        if (completed) return false
        complete()
        return true
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = android.widget.Button::class.java.name
    }

    private fun complete() {
        completed = true
        thumb.animate().translationX(maxTravel()).setDuration(SETTLE_DURATION_MS).start()
        label.alpha = 0f
        onCompleted?.invoke()
    }

    private fun setProgressX(x: Float) {
        val clamped = x.coerceIn(0f, maxTravel())
        thumb.translationX = clamped
        label.alpha = (1f - progress() * LABEL_FADE_FACTOR).coerceIn(0f, 1f)
    }

    private fun progress(): Float {
        val max = maxTravel()
        return if (max <= 0f) 0f else thumb.translationX / max
    }

    private fun maxTravel(): Float =
        (width - thumb.width - dp(THUMB_INSET_DP) * 2).coerceAtLeast(0f)

    private fun dp(value: Float): Float = value * resources.displayMetrics.density

    private fun View.setPadding(all: Int) = setPadding(all, all, all, all)

    private fun Int.withAlpha(alpha: Float): Int =
        Color.argb((alpha * 255).toInt(), Color.red(this), Color.green(this), Color.blue(this))
}
