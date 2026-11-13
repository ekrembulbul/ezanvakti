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
 *  Üç alarm: zaman çizelgesinin sonraki sınırına uyandıran kesin alarm (vakit
 *  ve kerahat geçişleri tam zamanında), cetvel noktası için 15 dk'da bir
 *  **uyandırmayan** tekrar (ekran kapalıyken pil harcamaz, açılınca gelir) ve
 *  vakte son bir saatte durum çubuğu ikonundaki dakika için yine
 *  uyandırmayan, yalnız sabit satırı yenileyen ikon alarmı.
 *
 *  Kendini onarma: hangi alarm gelirse gelsin üç alarmın hepsi yeniden
 *  kurulur. Bazı üreticilerin pil yöneticileri (Xiaomi, Samsung) arka
 *  plandaki uygulamanın alarmlarını düşürebiliyor; gelen tek bir alarm
 *  (ya da kullanıcının vakit alarmı) zinciri yeniden ayağa kaldırır. */
object SurfaceRefresher {
    private const val TAG = "EzanWidget"
    private const val BOUNDARY_REQUEST = 7401
    private const val TICK_REQUEST = 7402
    private const val ICON_REQUEST = 7403
    private const val REPOST_REQUEST = 7404
    /** Kesin alarm izni yoksa ikon alarmının gecikebileceği pencere. */
    private const val ICON_WINDOW_MILLIS = 10_000L
    private const val TICK_MILLIS = 15 * 60_000L
    const val ACTION_REFRESH = "com.ekrembulbul.ezanvakti.widget.REFRESH"
    const val ACTION_ICON = "com.ekrembulbul.ezanvakti.widget.STATUS_ICON"
    const val ACTION_REPOST = "com.ekrembulbul.ezanvakti.widget.REPOST"
    /** Alarmın kurulduğu an (ms); gecikmeyi loglamak için. */
    const val EXTRA_PLANNED_AT = "plannedAtMillis"

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

    /** İkon ve yeniden gösterme alarmı: yalnız sabit satırı yeniler;
     *  widget'lar dakikada bir yeniden çizilmez. Alarmların hepsi yine
     *  kurulur (kendini onarma). */
    fun refreshNotification(context: Context) {
        val app = context.applicationContext
        try {
            NextPrayerNotification.update(app)
        } catch (error: Exception) {
            Log.e(TAG, "event=next_prayer_failed type=" + error.javaClass.simpleName)
        }
        schedule(app)
    }

    /** Alıcıya gelen yenilemenin gecikmesini loglar: geç yenilenme
     *  şikâyetinde alarmın mı geciktiği, yoksa bildirimin mi düştüğü buradan
     *  ayrılır. Tekrar alarmı plan anı taşımaz. */
    fun logDelivery(action: String?, plannedAt: Long, receivedAt: Long = System.currentTimeMillis()) {
        val kind = when (action) {
            ACTION_ICON -> "icon"
            ACTION_REPOST -> "repost"
            ACTION_REFRESH -> "refresh"
            else -> "other"
        }
        val lateness = if (plannedAt > 0) (receivedAt - plannedAt).toString() else "na"
        Log.i(TAG, "event=surface_refresh kind=" + kind + " planned_ms=" + plannedAt +
            " received_ms=" + receivedAt + " lateness_ms=" + lateness)
    }

    private fun schedule(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val snapshot = currentSnapshot(context)
        val now = System.currentTimeMillis()
        scheduleIcon(context, am, snapshot, now)
        val tick = pendingIntent(context, TICK_REQUEST)
        if (snapshot == null) {
            am.cancel(pendingIntent(context, BOUNDARY_REQUEST))
            am.cancel(tick)
            return
        }
        val next = WidgetTimeline.nextBoundary(snapshot, now)
        val boundary = pendingIntent(context, BOUNDARY_REQUEST, plannedAt = next ?: 0L)
        Log.i(TAG, "event=surface_scheduled boundary_ms=" + (next ?: 0L))
        try {
            if (next == null) am.cancel(boundary)
            else if (canScheduleExact(am)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, boundary)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, boundary)
        } catch (error: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next ?: return, boundary)
        }
        am.setInexactRepeating(AlarmManager.RTC, now + TICK_MILLIS, TICK_MILLIS, tick)
    }

    /** Kaydırılan sabit satırı [at] anında yeniden gösterir (uyandırmaz:
     *  ekran kapalıysa açılınca gelir). */
    fun scheduleRepost(context: Context, at: Long) {
        val app = context.applicationContext
        val am = app.getSystemService(AlarmManager::class.java) ?: return
        val repost = pendingIntent(app, REPOST_REQUEST, ACTION_REPOST, at)
        try {
            if (canScheduleExact(am)) am.setExact(AlarmManager.RTC, at, repost)
            else am.setWindow(AlarmManager.RTC, at, ICON_WINDOW_MILLIS, repost)
        } catch (error: SecurityException) {
            am.setWindow(AlarmManager.RTC, at, ICON_WINDOW_MILLIS, repost)
        }
    }

    private fun scheduleIcon(context: Context, am: AlarmManager, snapshot: WidgetSnapshot?, now: Long) {
        val target = snapshot?.let { WidgetTimeline.state(it, now) }?.takeUnless { it.stale }?.next?.epochMillis
        val at = target?.let { StatusIconCountdown.nextChange(it, now) }
        val icon = pendingIntent(context, ICON_REQUEST, ACTION_ICON, at ?: 0L)
        if (at == null || !WidgetStore.notificationEnabled(context)) {
            am.cancel(icon)
            return
        }
        try {
            if (canScheduleExact(am)) am.setExact(AlarmManager.RTC, at, icon)
            else am.setWindow(AlarmManager.RTC, at, ICON_WINDOW_MILLIS, icon)
        } catch (error: SecurityException) {
            am.setWindow(AlarmManager.RTC, at, ICON_WINDOW_MILLIS, icon)
        }
    }

    private fun currentSnapshot(context: Context): WidgetSnapshot? =
        (WidgetSnapshotParser.parse(WidgetStore.snapshotJson(context)) as? SnapshotResult.Ok)?.snapshot

    private fun canScheduleExact(am: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    /** Aynı istek kodu ve eylem aynı alarmı gösterir; [plannedAt] ek veridir,
     *  alarmın kimliğini değiştirmez (iptal de aynı alarmı bulur). */
    private fun pendingIntent(
        context: Context,
        request: Int,
        action: String = ACTION_REFRESH,
        plannedAt: Long = 0L,
    ): PendingIntent = PendingIntent.getBroadcast(
        context, request,
        Intent(context, SurfaceRefreshReceiver::class.java).setAction(action).putExtra(EXTRA_PLANNED_AT, plannedAt),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
