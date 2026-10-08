package com.ekrembulbul.ezanvakti.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF

/** Ana ekran cetvelinin (`day_ruler.dart`) bitmap karşılığı: gündüz vurgu,
 *  gece soluk, kerahat bordo; vakit sınırlarında gerçek boşluk, altta
 *  çentikler, şu an noktası. Saat etiketi bitmap'te değil, layout'taki
 *  `TextClock`'ta (canlı akar). */
object RulerBitmap {
    /** Toplam yükseklik: nokta (14) + çentik payı. */
    const val HEIGHT_DP = 22f
    private const val TRACK_DP = 5f
    private const val DOT_DP = 14f
    private const val DOT_INNER_DP = 8f
    private const val TICK_W_DP = 2f
    private const val TICK_H_DP = 6f
    private const val TICK_GAP_DP = 2f
    private const val MARK_GAP_PX = 3f

    /** Yatağın dikey merkezi (bitmap içinde, px). */
    fun trackCenterPx(density: Float): Float = DOT_DP / 2 * density

    /** Noktanın yatay merkezi; kenarlarda taşmasın diye kırpılır. */
    fun dotCenterPx(widthPx: Int, density: Float, nowFraction: Float): Float {
        val half = DOT_DP / 2 * density
        return (widthPx * nowFraction).coerceIn(half, (widthPx - half).coerceAtLeast(half))
    }

    fun draw(
        widthPx: Int,
        density: Float,
        parts: List<RulerPart>,
        marks: List<Float>,
        nowFraction: Float?,
        palette: Palette,
        background: Int,
    ): Bitmap {
        val width = widthPx.coerceAtLeast(1)
        val height = (HEIGHT_DP * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

        val center = trackCenterPx(density)
        val track = TRACK_DP * density
        val top = center - track / 2
        val radius = track / 2
        for (part in parts) {
            val gapBefore = if (part.gapBefore) MARK_GAP_PX / 2 else 0f
            val gapAfter = if (part.gapAfter) MARK_GAP_PX / 2 else 0f
            val left = part.start * width + gapBefore
            val right = part.end * width - gapAfter
            if (right <= left) continue
            paint.color = when (part.kind) {
                RulerPart.Kind.DAY -> palette.accent
                RulerPart.Kind.NIGHT -> palette.night
                RulerPart.Kind.KERAHAT -> palette.kerahatLine
            }
            // Yalnız gün uçlarında ve vakit boşluklarında yuvarlak köşe; kerahat
            // sınırları düz birleşir (ana ekrandaki gibi).
            val roundLeft = part.start == 0f || part.gapBefore
            val roundRight = part.end == 1f || part.gapAfter
            val rect = RectF(left, top, right, top + track)
            val radii = floatArrayOf(
                if (roundLeft) radius else 0f, if (roundLeft) radius else 0f,
                if (roundRight) radius else 0f, if (roundRight) radius else 0f,
                if (roundRight) radius else 0f, if (roundRight) radius else 0f,
                if (roundLeft) radius else 0f, if (roundLeft) radius else 0f,
            )
            canvas.drawPath(Path().apply { addRoundRect(rect, radii, Path.Direction.CW) }, paint)
        }

        paint.color = palette.tick
        val tickW = TICK_W_DP * density
        val tickTop = top + track + TICK_GAP_DP * density
        for (mark in marks) {
            val x = (width - tickW) * mark
            canvas.drawRoundRect(RectF(x, tickTop, x + tickW, tickTop + TICK_H_DP * density), tickW / 2, tickW / 2, paint)
        }

        if (nowFraction != null) {
            val x = dotCenterPx(width, density, nowFraction)
            // Dış halka zemin renginde: nokta yatağın üstünde ayrışsın.
            paint.color = background
            canvas.drawCircle(x, center, DOT_DP / 2 * density, paint)
            paint.color = palette.accent
            canvas.drawCircle(x, center, DOT_INNER_DP / 2 * density, paint)
        }
        return bitmap
    }
}
