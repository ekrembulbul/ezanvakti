package com.ekrembulbul.ezanvakti

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

/** Alarm çalarken ön planda çalışan servis: sesi (alarm akışında, döngüde) çalar,
 *  titreşir ve tam ekran çalar ekranını açan bir bildirim gösterir. Kapat/ertele
 *  eylemlerini yönetir. */
class AlarmRingService : Service() {
    companion object {
        const val ACTION_START = "com.ekrembulbul.ezanvakti.RING_START"
        const val ACTION_STOP = "com.ekrembulbul.ezanvakti.RING_STOP"
        const val ACTION_SNOOZE = "com.ekrembulbul.ezanvakti.RING_SNOOZE"
        const val CHANNEL_ID = "ezan_vakti_alarm_channel"
        const val NOTIF_ID = 9911
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var current: AlarmArgs? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopRinging()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                snooze()
                return START_NOT_STICKY
            }
            else -> {
                val args = AlarmArgs.readFrom(intent ?: Intent())
                current = args
                startForeground(NOTIF_ID, buildNotification(args))
                startRinging(args)
            }
        }
        return START_STICKY
    }

    private fun buildNotification(args: AlarmArgs): Notification {
        createChannel()
        val fullScreen = Intent(this, AlarmRingActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            args.writeTo(this)
        }
        val fsPending = PendingIntent.getActivity(
            this,
            args.id.hashCode(),
            fullScreen,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (args.label.isNotBlank()) args.label else "Ezan Vakti & Alarm"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText("Alarm çalıyor")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fsPending, true)
            .build()
    }

    private fun startRinging(args: AlarmArgs) {
        // Faz 4'te soundId -> gömülü ses (raw) eşlenecek; şimdilik varsayılan alarm sesi.
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(this@AlarmRingService, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            // Ses çalınamazsa alarm yine de görünür kalır.
        }
        if (args.vibrate) startVibrate()
    }

    private fun startVibrate() {
        @Suppress("DEPRECATION")
        val vib = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        vibrator = vib
        val pattern = longArrayOf(0, 700, 600)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(pattern, 0)
        }
    }

    private fun stopRinging() {
        player?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        vibrator?.cancel()
        vibrator = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun snooze() {
        val args = current
        if (args != null && args.snoozeEnabled) {
            val next = System.currentTimeMillis() + args.snoozeMinutes * 60_000L
            AlarmScheduling.schedule(this, args.copy(timeMillis = next))
        }
        stopRinging()
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "Ezan Vakti Alarmları",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Sesli alarmlar"
                    // Ses servis tarafından (alarm akışında) çalınır; kanal sessiz.
                    setSound(null, null)
                    enableVibration(false)
                    setBypassDnd(true)
                }
                mgr.createNotificationChannel(ch)
            }
        }
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }
}
