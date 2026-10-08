package com.ekrembulbul.ezanvakti.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Ana ekran widget'larını ve sabit "sıradaki vakit" satırını birlikte çizer,
 *  bir sonraki tazelemeyi kurar.
 *
 *  İki alarm: zaman çizelgesinin sonraki sınırına uyandıran kesin alarm (vakit
 *  ve kerahat geçişleri tam zamanında), cetvel noktası için 15 dk'da bir
 *  **uyandırmayan** tekrar (ekran kapalıyken pil harcamaz, açılınca gelir). */
object SurfaceRefresher {
    private const val TAG = "EzanWidget"
    private const val BOUNDARY_REQUEST = 7401
    private const val TICK_REQUEST = 7402
    private const val TICK_MILLIS = 15 * 60_000L
    const val ACTION_REFRESH = "com.ekrembulbul.ezanvakti.widget.REFRESH"

    fun refreshAll(context: Context) {
        val app = context.applicationContext
        try {
            EzanWidgetProvider.updateAll(app)
        } catch (error: Exception) {
            Log.e(TAG, "event=widget_render_failed type=" + error.javaClass.simpleName)
        }
        try {
            NextPrayerNotification.update(app)
        } catch (error: Exception) {
            Log.e(TAG, "event=next_prayer_failed type=" + error.javaClass.simpleName)
        }
        schedule(app)
    }

    private fun schedule(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val boundary = pendingIntent(context, BOUNDARY_REQUEST)
        val tick = pendingIntent(context, TICK_REQUEST)
        val snapshot = (WidgetSnapshotParser.parse(WidgetStore.snapshotJson(context)) as? SnapshotResult.Ok)?.snapshot
        if (snapshot == null) {
            am.cancel(boundary)
            am.cancel(tick)
            return
        }
        val now = System.currentTimeMillis()
        val next = WidgetTimeline.nextBoundary(snapshot, now)
        try {
            if (next == null) am.cancel(boundary)
            else if (canScheduleExact(am)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, boundary)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, boundary)
        } catch (error: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next ?: return, boundary)
        }
        am.setInexactRepeating(AlarmManager.RTC, now + TICK_MILLIS, TICK_MILLIS, tick)
    }

    private fun canScheduleExact(am: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    private fun pendingIntent(context: Context, request: Int): PendingIntent = PendingIntent.getBroadcast(
        context, request,
        Intent(context, SurfaceRefreshReceiver::class.java).setAction(ACTION_REFRESH),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
