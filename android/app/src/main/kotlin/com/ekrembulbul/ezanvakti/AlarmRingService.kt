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
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

/** Alarm çalarken ön planda çalışan servis: sesi (alarm akışında, döngüde) çalar,
 *  titreşir ve tam ekran çalar ekranını açan bir bildirim gösterir. Kapat/ertele
 *  eylemlerini yönetir. */
class AlarmRingService : Service() {
    companion object {
        const val ACTION_START = "com.ekrembulbul.ezanvakti.RING_START"
        const val ACTION_STOP = "com.ekrembulbul.ezanvakti.RING_STOP"
        const val ACTION_CANCEL = "com.ekrembulbul.ezanvakti.RING_CANCEL"
        const val CHANNEL_ID = "ezan_vakti_alarm_channel"
        const val NOTIF_ID = 9911
        @Volatile private var ringingAlarmId: String? = null

        fun cancelForAlarm(context: Context, alarmId: String, firedAtMillis: Long? = null) {
            if (ringingAlarmId != alarmId) return
            context.startService(Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_CANCEL
                putExtra("alarmId", alarmId)
                if (firedAtMillis != null) putExtra("firedAtMillis", firedAtMillis)
            })
        }
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var current: AlarmArgs? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                val requested = AlarmArgs.readFrom(intent)
                val active = current
                if (active == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (requested.id == active.id && requested.timeMillis == active.timeMillis) {
                    if (recordStop(active)) {
                        stopRinging()
                        current = null
                        ringingAlarmId = null
                        stopSelf()
                        return START_NOT_STICKY
                    }
                }
                return START_STICKY
            }
            ACTION_CANCEL -> {
                if (current == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                val active = current!!
                val expected = if (intent.hasExtra("firedAtMillis")) intent.getLongExtra("firedAtMillis", 0) else null
                if (active.alarmId == intent.getStringExtra("alarmId") &&
                    (expected == null || expected == (active.originalFireAtMillis ?: active.timeMillis))) {
                    stopRinging()
                    current = null
                    ringingAlarmId = null
                    stopSelf()
                    return START_NOT_STICKY
                }
                return START_STICKY
            }
            else -> {
                val missions = AndroidMissionStore.missions(this)
                val args = if (intent == null) missions.ringing() else AlarmArgs.readFrom(intent)
                val receivedAt = intent?.getLongExtra("receivedAtMillis", System.currentTimeMillis()) ?: System.currentTimeMillis()
                if (args == null || !missions.fired(args, receivedAt)) {
                    if (current == null) stopSelf()
                    return if (current == null) START_NOT_STICKY else START_STICKY
                }
                current?.takeIf { it.id != args.id }?.let { recordStop(it) }
                stopRinging()
                current = args
                ringingAlarmId = args.alarmId
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
            data = AlarmScheduling.intentData(args.id, "ring")
            args.writeTo(this)
        }
        val fsPending = PendingIntent.getActivity(
            this,
            args.id.hashCode(),
            fullScreen,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = if (args.label.isNotBlank()) args.label
        else getString(R.string.alarm_default_label)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(getString(R.string.alarm_ringing))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fsPending, true)
            .build()
    }

    private fun startRinging(args: AlarmArgs) {
        val uri = soundUriFor(args.soundId)
        if (uri != null) try {
            val playback = MediaPlayer()
            player = playback
            playback.apply {
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
            Log.i("EzanAlarm", "event=audio_started id=" + args.id + " audio_ms=" + System.currentTimeMillis())
        } catch (error: Exception) {
            // Ses çalınamazsa alarm yine de görünür kalır.
            Log.e("EzanAlarm", "event=audio_failed id=" + args.id + " type=" + error.javaClass.simpleName)
        }
        if (args.vibrate) startVibrate()
    }

    /** soundId res/raw altında bir kaynağa (ör. raw/adhan) karşılık geliyorsa onu,
     *  yoksa sistemin varsayılan alarm sesini döner. Gömülü ses dosyaları
     *  eklendiğinde (raw/<soundId>) ek koda gerek kalmadan çalışır. */
    private fun soundUriFor(soundId: String): Uri? {
        if (soundId.startsWith("custom:")) {
            val file = File(filesDir, "alarm_sounds/${soundId.removePrefix("custom:")}")
            if (file.exists()) return Uri.fromFile(file)
        } else if (soundId.isNotBlank() && soundId != "default") {
            val resId = resources.getIdentifier(soundId, "raw", packageName)
            if (resId != 0) {
                return Uri.parse("android.resource://$packageName/$resId")
            }
        }
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
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

    private fun recordStop(args: AlarmArgs): Boolean {
        return try {
            val missions = AndroidMissionStore.missions(this)
            val previous = missions.session(args.alarmId)
            val stopped = missions.stop(args, System.currentTimeMillis()) ?: return false
            var armed = true
            if (stopped.rearmAtMillis != null) {
                try { AlarmScheduling.rearm(this, stopped.session, stopped.rearmAtMillis) }
                catch (error: Exception) {
                    armed = false
                    if (previous != null && missions.session(args.alarmId)?.timerScheduleId == previous.timerScheduleId) {
                        missions.restore(previous)
                    }
                    Log.e("EzanAlarm", "event=watchdog_failed id=" + args.alarmId + " type=" + error.javaClass.simpleName)
                    AlarmJournal(this).record("stop_rearm", args, result = "failed", error = error)
                }
            }
            if (args.opensApp) AlarmChannel.notifyStopped(stopped.event)
            AlarmJournal(this).record("stopped", args)
            // If rearming fails, keep the sound until the task is completed.
            armed || !args.missionEnabled
        } catch (error: Exception) {
            Log.e("EzanAlarm", "event=stop_failed id=" + args.alarmId + " type=" + error.javaClass.simpleName)
            false
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.alarm_channel_name),
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = getString(R.string.alarm_channel_description)
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
        current = null
        ringingAlarmId = null
        super.onDestroy()
    }
}
