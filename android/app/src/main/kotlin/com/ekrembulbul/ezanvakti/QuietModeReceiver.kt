package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Sessiz pencere sınırında (başlangıç ya da bitiş) planı yeniden uygular. */
class QuietModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        QuietModeController.reapply(context)
    }
}
