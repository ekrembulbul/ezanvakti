package com.ekrembulbul.ezanvakti.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/** Ana ekran widget'ı (spec K6–K8, D10–D12).
 *
 *  Çizimi [WidgetRenderer] yapar; tazeleme ritmi [SurfaceRefresher]'da.
 *  `APPWIDGET_UPDATE` yayını hem sistemden (widget eklendi) hem Dart'tan
 *  (`home_widget` yayını) gelir: ikisinde de widget'lar, sabit satır ve sonraki
 *  tazeleme alarmı birlikte kurulur. Widget yokken de (id listesi boş) sabit
 *  satır tazelenmeli; bu yüzden id listesine bakılmaz. */
class EzanWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "EzanWidget"

        /** Kurulu bütün widget'ları çizer. Yayın göndermez, doğrudan
         *  `updateAppWidget` çağırır: [SurfaceRefresher.refreshAll] buradan
         *  çağrıldığı için döngü kurulmaz. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, EzanWidgetProvider::class.java))
            if (ids == null || ids.isEmpty()) return
            update(context, manager, ids)
        }

        private fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val now = System.currentTimeMillis()
            val inputs = try {
                WidgetRenderer.Inputs.load(context)
            } catch (error: Exception) {
                Log.e(TAG, "event=widget_inputs_failed type=" + error.javaClass.simpleName)
                return
            }
            for (id in ids) {
                // Tek widget'ın çizim hatası diğerlerini durdurmasın.
                try {
                    manager.updateAppWidget(id, WidgetRenderer.views(context, manager, id, now, inputs))
                } catch (error: Exception) {
                    Log.e(TAG, "event=widget_update_failed type=" + error.javaClass.simpleName)
                }
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            // refreshAll bütün widget'ları çizer; `super` yalnız onUpdate'i
            // çağırırdı, aynı widget'lar iki kez çizilmesin diye atlanır.
            SurfaceRefresher.refreshAll(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        update(context, manager, ids)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        newOptions: Bundle,
    ) {
        // Boyut değişti: küçük/orta seçimi ve bitmap'ler yeni ölçüye göre.
        update(context, manager, intArrayOf(widgetId))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        for (id in ids) WidgetStore.removeAlignment(context, id)
    }
}
