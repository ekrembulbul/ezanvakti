package com.ekrembulbul.ezanvakti.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import com.ekrembulbul.ezanvakti.R
import kotlin.math.roundToInt

/** Durum çubuğu ikonu: uygulamanın durum çubuğu ikonundaki çapraz hilal,
 *  camisi çıkarılmış, içinde kalan dakika.
 *
 *  Hilal `ic_stat_crescent` (nodpi, 96 px): `ic_stat_notification`'ın en
 *  yüksek çözünürlüğünden yalnız cami silinerek üretildi; şekli ve konumu
 *  normal ikonla birebir aynı. Sistem küçük ikonu yalnız saydamlığıyla okur
 *  ve kendi rengine boyar; rakam beyaz çizilir (tasarım 2026-11-01). */
object StatusIconBitmap {
    /** Android'in durum çubuğu ikon kutusu (dp). */
    private const val ICON_DP = 24f

    /** Rakamın ortası: caminin kapladığı alanın ortası (kare kenarına oran). */
    private const val TEXT_CENTER_X = 0.60f
    private const val TEXT_CENTER_Y = 0.49f
    private const val TEXT_SIZE_TWO_DIGITS = 0.50f
    private const val TEXT_SIZE_ONE_DIGIT = 0.58f

    private var crescent: Bitmap? = null

    fun draw(context: Context, minutes: Int): Bitmap {
        val size = (ICON_DP * context.resources.displayMetrics.density).roundToInt().coerceAtLeast(24)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val s = size.toFloat()

        crescent(context)?.let {
            canvas.drawBitmap(it, null, RectF(0f, 0f, s, s), Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG))
        }

        val text = minutes.toString()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
            textAlign = Paint.Align.CENTER
            textSize = s * if (text.length >= 2) TEXT_SIZE_TWO_DIGITS else TEXT_SIZE_ONE_DIGIT
        }
        // Rakamın görsel ortası hedefe gelsin (taban çizgisi değil).
        val bounds = Rect()
        paint.getTextBounds(text, 0, text.length, bounds)
        canvas.drawText(text, s * TEXT_CENTER_X, s * TEXT_CENTER_Y - bounds.exactCenterY(), paint)
        return bitmap
    }

    private fun crescent(context: Context): Bitmap? =
        crescent ?: BitmapFactory.decodeResource(
            context.resources,
            R.drawable.ic_stat_crescent,
            BitmapFactory.Options().apply { inScaled = false },
        )?.also { crescent = it }
}
