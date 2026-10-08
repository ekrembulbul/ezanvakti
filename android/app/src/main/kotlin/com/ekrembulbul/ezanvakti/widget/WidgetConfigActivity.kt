package com.ekrembulbul.ezanvakti.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.RadioGroup
import com.ekrembulbul.ezanvakti.R

/** Küçük widget'ın hizalama ayarı (spec K7, D11): sola, ortaya, sağa.
 *
 *  Android 12 öncesinde widget yerleştirilirken açılır; 12+'da ayar isteğe
 *  bağlı (`configuration_optional`) ve sonradan "Widget ayarları"yla açılır.
 *  Kaydetmeden çıkmak iptal sayılır: yerleştirmedeyse sistem widget'ı eklemez. */
class WidgetConfigActivity : Activity() {
    companion object {
        private const val TAG = "EzanWidget"
    }

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // Geri, dışarı dokunma ya da süreç ölümü: sonuç iptal kalır.
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_config)
        val group = findViewById<RadioGroup>(R.id.widget_align_group)
        if (savedInstanceState == null) {
            group.check(buttonFor(WidgetStore.alignment(this, widgetId)))
        }
        findViewById<Button>(R.id.widget_config_save).setOnClickListener {
            WidgetStore.setAlignment(this, widgetId, valueFor(group.checkedRadioButtonId))
            try {
                EzanWidgetProvider.updateAll(this)
            } catch (error: Exception) {
                Log.e(TAG, "event=widget_config_update_failed type=" + error.javaClass.simpleName)
            }
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result(): Intent = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    private fun buttonFor(alignment: Int): Int = when (alignment) {
        WidgetStore.ALIGN_START -> R.id.widget_align_start
        WidgetStore.ALIGN_END -> R.id.widget_align_end
        else -> R.id.widget_align_center
    }

    private fun valueFor(buttonId: Int): Int = when (buttonId) {
        R.id.widget_align_start -> WidgetStore.ALIGN_START
        R.id.widget_align_end -> WidgetStore.ALIGN_END
        else -> WidgetStore.ALIGN_CENTER
    }
}
