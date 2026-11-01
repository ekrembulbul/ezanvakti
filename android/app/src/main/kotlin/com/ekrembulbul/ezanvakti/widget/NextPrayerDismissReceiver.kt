package com.ekrembulbul.ezanvakti.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Sabit satır kaydırılınca (Android 14+ `setOngoing` bildirimi kullanıcı
 *  kaldırabiliyor) ayar açıksa satırı bir dakika sonra yeniden gösterir.
 *  Android 13 ve öncesinde satır kaydırılamaz; bu alıcı yalnız "kaldırıldı"
 *  olayında çalışır, uygulamanın kendi `cancel` çağrısında tetiklenmez. */
class NextPrayerDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!WidgetStore.notificationEnabled(context)) return
        try {
            val until = NextPrayerNotification.hideAfterDismiss(context)
            SurfaceRefresher.scheduleRepost(context, until)
        } catch (error: Exception) {
            Log.e("EzanWidget", "event=next_prayer_repost_failed type=" + error.javaClass.simpleName)
        }
    }
}
