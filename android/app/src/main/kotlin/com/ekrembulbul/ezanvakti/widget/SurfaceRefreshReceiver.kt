package com.ekrembulbul.ezanvakti.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Çizelge sınırında ve 15 dk'lık tekrarda widget'ları ve sabit satırı tazeler;
 *  ikon alarmında (son bir saatte dakikada bir) ve kaydırılan satırın geri
 *  geldiği alarmda yalnız sabit satırı. */
class SurfaceRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SurfaceRefresher.logDelivery(intent.action, intent.getLongExtra(SurfaceRefresher.EXTRA_PLANNED_AT, 0L))
        when (intent.action) {
            SurfaceRefresher.ACTION_ICON, SurfaceRefresher.ACTION_REPOST ->
                SurfaceRefresher.refreshNotification(context)
            else -> SurfaceRefresher.refreshAll(context)
        }
    }
}
