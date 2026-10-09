package com.ekrembulbul.ezanvakti

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.util.Date

/** Alarm çalarken ön planda çalışan servis: sesi (alarm akışında, döngüde) çalar,
 *  titreşir ve tam ekran çalar ekranını açan bir bildirim gösterir. Kapat/ertele
 *  eylemlerini yönetir. Çalarken alarm akışının seviyesini sabit tutar ve
 *  çalma süresi sınırı dolunca alarmı erteler ya da durdurur. */
class AlarmRingService : Service() {
    companion object {
        const val ACTION_START = "com.ekrembulbul.ezanvakti.RING_START"
        const val ACTION_STOP = "com.ekrembulbul.ezanvakti.RING_STOP"
        const val ACTION_CANCEL = "com.ekrembulbul.ezanvakti.RING_CANCEL"
        /** Alıcı servisi startForegroundService ile başlattı: servis ön plana geçmeli. */
        const val EXTRA_FOREGROUND_START = "foregroundStart"
        const val CHANNEL_ID = "ezan_vakti_alarm_channel"
        const val NOTIF_ID = 9911

        /** Ses yükselişi: bu süre boyunca START_VOLUME'dan tam sese çıkar. */
        const val FADE_IN_MILLIS = 5_000L
        const val FADE_IN_STEP_MILLIS = 100L
        /** Sıfırdan değil: sessiz başlayan alarm ilk saniyelerde hiç duyulmayabilir. */
        const val FADE_IN_START_VOLUME = 0.2f

        /** Ses tuşuyla değişen seviye bu aralıkla geri alınır. */
        const val VOLUME_GUARD_MILLIS = 500L

        /** Süre dolup bir daha çalmayacak alarmın bilgi bildirimi. */
        const val MISSED_CHANNEL_ID = "ezan_vakti_alarm_missed"
        const val MISSED_NOTIF_BASE = 9_920_000
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
    private val fadeHandler = Handler(Looper.getMainLooper())
    private var fadeStartedAt = 0L
    private var vibrator: Vibrator? = null
    private var current: AlarmArgs? = null

    /** Çalma başlamadan önceki alarm seviyesi; bitince geri yüklenir. */
    private var restoreVolumeIndex: Int? = null
    private var lockedVolumeIndex: Int? = null

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
                    if (current == null) {
                        if (intent?.getBooleanExtra(EXTRA_FOREGROUND_START, false) == true) settleForegroundStart()
                        stopSelf()
                    }
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
        // Ses başlamadan seviye ayarlanır: ilk saniye yanlış seviyede çalmasın.
        lockVolume(args)
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
                if (args.fadeIn) setVolume(FADE_IN_START_VOLUME, FADE_IN_START_VOLUME)
                start()
            }
            if (args.fadeIn) startFadeIn(playback)
            Log.i("EzanAlarm", "event=audio_started id=" + args.id + " audio_ms=" + System.currentTimeMillis())
        } catch (error: Exception) {
            // Ses çalınamazsa alarm yine de görünür kalır.
            Log.e("EzanAlarm", "event=audio_failed id=" + args.id + " type=" + error.javaClass.simpleName)
        }
        if (args.vibrate) startVibrate()
        startRingTimeout(args)
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

    /**
     * Sesi [FADE_IN_START_VOLUME] seviyesinden tam sese çıkarır.
     *
     * `setVolume` uygulama içi bir çarpandır: kullanıcının sistem alarm ses
     * seviyesine dokunmaz, yalnızca onun içinde bir oran uygular.
     */
    private fun startFadeIn(playback: MediaPlayer) {
        fadeStartedAt = System.currentTimeMillis()
        val startedAt = fadeStartedAt
        val step = object : Runnable {
            override fun run() {
                // Alarm durduysa ya da yeni bir çalış başladıysa bu ramp ölür.
                if (player !== playback || fadeStartedAt != startedAt) return
                val elapsed = System.currentTimeMillis() - startedAt
                val progress = (elapsed.toFloat() / FADE_IN_MILLIS).coerceIn(0f, 1f)
                val volume = FADE_IN_START_VOLUME + (1f - FADE_IN_START_VOLUME) * progress
                try {
                    playback.setVolume(volume, volume)
                } catch (error: IllegalStateException) {
                    // Oynatıcı arada serbest bırakılmış olabilir; ramp burada biter.
                    return
                }
                if (progress < 1f) fadeHandler.postDelayed(this, FADE_IN_STEP_MILLIS)
            }
        }
        fadeHandler.post(step)
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
        fadeStartedAt = 0L
        // Ses yükselişi, seviye koruyucusu ve süre zamanlayıcısı birlikte biter.
        fadeHandler.removeCallbacksAndMessages(null)
        unlockVolume()
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
        removeForeground()
    }

    private fun removeForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    /** Ön plan başlatması reddedilen bir teslimle bitti (alıcıdaki elemeyle yarışan
     *  atlama ya da yinelenen teslim): Android, ön plana geçmeden kapanan servisin
     *  sürecini öldürür. Sessiz bir bildirimle ön plana geçilip hemen çıkılır. */
    private fun settleForegroundStart() {
        try {
            createChannel()
            startForeground(NOTIF_ID, NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notification)
                .setContentTitle(getString(R.string.alarm_default_label))
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setSilent(true)
                .build())
            removeForeground()
        } catch (error: Exception) {
            Log.e("EzanAlarm", "event=foreground_settle_failed type=" + error.javaClass.simpleName)
        }
    }

    /**
     * Alarm çalarken alarm akışı hedef seviyede sabit kalır: çalar ekranı önde
     * değilken basılan ses tuşları da geri alınır. Bitince kullanıcının önceki
     * seviyesi geri yüklenir. Yüzde verilmemişse hedef, o anki seviyedir.
     */
    private fun lockVolume(args: AlarmArgs) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val stream = AudioManager.STREAM_ALARM
        val current = audio.getStreamVolume(stream)
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) audio.getStreamMinVolume(stream) else 0
        val target = AlarmVolume.targetIndex(args.volumePercent, current, min, audio.getStreamMaxVolume(stream))
        try {
            if (target != current) audio.setStreamVolume(stream, target, 0)
        } catch (error: SecurityException) {
            // Örn. tam sessiz Rahatsız Etme: alarm mevcut seviyede çalar.
            AlarmJournal(this).record("volume_lock", args, result = "failed", error = error)
            return
        }
        restoreVolumeIndex = current
        lockedVolumeIndex = target
        val guard = object : Runnable {
            override fun run() {
                val locked = lockedVolumeIndex ?: return
                try {
                    if (audio.getStreamVolume(stream) != locked) audio.setStreamVolume(stream, locked, 0)
                } catch (_: SecurityException) {
                    return
                }
                fadeHandler.postDelayed(this, VOLUME_GUARD_MILLIS)
            }
        }
        fadeHandler.postDelayed(guard, VOLUME_GUARD_MILLIS)
    }

    private fun unlockVolume() {
        val restore = restoreVolumeIndex
        lockedVolumeIndex = null
        restoreVolumeIndex = null
        if (restore == null) return
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            if (audio.getStreamVolume(AudioManager.STREAM_ALARM) != restore) {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, restore, 0)
            }
        } catch (_: SecurityException) {
        }
    }

    private fun startRingTimeout(args: AlarmArgs) {
        val delay = RingTimeout.delayMillis(args.ringLimitMinutes) ?: return
        fadeHandler.postDelayed({
            val active = current
            if (active != null && active.id == args.id && active.timeMillis == args.timeMillis) {
                onRingTimeout(active)
            }
        }, delay)
    }

    /** Süre doldu: erteleme hakkı varsa mevcut erteleme geçişi, yoksa
     *  kaydırarak durdurmayla aynı yol (görevli alarmda nöbetçi zinciri sürer). */
    private fun onRingTimeout(args: AlarmArgs) {
        val missions = AndroidMissionStore.missions(this)
        val previous = missions.session(args.alarmId)
        val snoozed = if (args.snoozeEnabled) {
            missions.snooze(args.alarmId, args.snoozeMinutes, System.currentTimeMillis())
        } else null
        if (snoozed != null) {
            try {
                AlarmScheduling.rearm(this, snoozed, requireNotNull(snoozed.snoozedUntilMillis))
                AlarmJournal(this).record("ring_timeout_snooze", args)
                finishRinging()
                return
            } catch (error: Exception) {
                if (previous != null && missions.session(args.alarmId)?.timerScheduleId == previous.timerScheduleId) {
                    missions.restore(previous)
                }
                AlarmJournal(this).record("ring_timeout_snooze", args, result = "failed", error = error)
            }
        }
        if (!recordStop(args)) {
            // Durdurma reddedildi (görev zinciri kurulamadı): ses görev
            // bitene dek sürer; zamanlayıcı yeniden kurulmaz.
            AlarmJournal(this).record("ring_timeout_stop", args, result = "failed")
            return
        }
        val chainContinues = missions.session(args.alarmId)?.deadlineMillis != null
        AlarmJournal(this).record("ring_timeout_stop", args)
        if (RingTimeout.missedNotice(args.missionEnabled, chainContinues)) postMissed(args)
        finishRinging()
    }

    /** Servis alarmı kendisi bitirdi: ekran da kapanır, aksi halde kilit
     *  ekranında susmuş bir "Alarm çalıyor" ekranı kalırdı. */
    private fun finishRinging() {
        stopRinging()
        current = null
        ringingAlarmId = null
        AlarmRingActivity.finishShowing()
        stopSelf()
    }

    private fun postMissed(args: AlarmArgs) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(MISSED_CHANNEL_ID) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(
                    MISSED_CHANNEL_ID,
                    getString(R.string.alarm_missed_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            ("missed" + args.alarmId).hashCode(),
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val firedAt = args.originalFireAtMillis ?: args.timeMillis
        val time = android.text.format.DateFormat.getTimeFormat(this).format(Date(firedAt))
        val notification = NotificationCompat.Builder(this, MISSED_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(args.label.ifBlank { getString(R.string.alarm_default_label) })
            .setContentText(getString(R.string.alarm_missed_text, time))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            // Aynı alarmın yeni kaçırılışı eskisinin yerine geçer.
            manager.notify(MISSED_NOTIF_BASE + (args.alarmId.hashCode() and 0xFFFF), notification)
        } catch (_: SecurityException) {
            // Bildirim izni yok: bilgi notu gösterilemez, alarm akışı etkilenmez.
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
