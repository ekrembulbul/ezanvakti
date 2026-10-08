package com.ekrembulbul.ezanvakti.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Çizelge sınırında ve 15 dk'lık tekrarda widget'ları ve sabit satırı tazeler. */
class SurfaceRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SurfaceRefresher.refreshAll(context)
    }
}
