package com.ekrembulbul.ezanvakti.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader

/** Widget zemini: gün diliminin radyal gradyanı, iOS `Palette.backgroundGradient`
 *  geometrisiyle aynı (merkez 0.70w, −0.04h; yarıçap kısa kenar × 1.25;
 *  duraklar 0 / 0.44 / 1). Köşeler yuvarlatılmış çizilir. */
object BackgroundBitmap {
    fun draw(widthPx: Int, heightPx: Int, radiusPx: Float, stops: IntArray): Bitmap {
        val width = widthPx.coerceAtLeast(1)
        val height = heightPx.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = minOf(width, height) * 1.25f
        val colors = if (stops.size == 3) stops else intArrayOf(0xFF2A2038.toInt(), 0xFF17111F.toInt(), 0xFF0A080E.toInt())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                width * 0.70f, height * -0.04f, radius,
                colors, floatArrayOf(0f, 0.44f, 1f), Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radiusPx, radiusPx, paint)
        return bitmap
    }
}
