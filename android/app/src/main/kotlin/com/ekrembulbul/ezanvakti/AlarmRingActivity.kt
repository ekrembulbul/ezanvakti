package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

/** Alarm çalarken kilit ekranının üstünde açılan tam ekran çalar ekranı. */
class AlarmRingActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockscreen()
        setContentView(R.layout.activity_alarm_ring)

        val args = AlarmArgs.readFrom(intent)
        findViewById<TextView>(R.id.alarm_title).text =
            if (args.label.isNotBlank()) args.label else "Ezan Vakti & Alarm"

        findViewById<Button>(R.id.alarm_dismiss).setOnClickListener {
            sendToService(AlarmRingService.ACTION_STOP, args)
            finish()
        }

        val snooze = findViewById<Button>(R.id.alarm_snooze)
        if (args.snoozeEnabled) {
            snooze.text = getString(
                R.string.alarm_snooze_minutes,
                args.snoozeMinutes,
            )
            snooze.setOnClickListener {
                sendToService(AlarmRingService.ACTION_SNOOZE, args)
                finish()
            }
        } else {
            snooze.visibility = View.GONE
        }
    }

    private fun showOverLockscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
    }

    private fun sendToService(action: String, args: AlarmArgs) {
        val i = Intent(this, AlarmRingService::class.java).apply {
            this.action = action
            args.writeTo(this)
        }
        startService(i)
    }

    // Geri tuşuyla alarm kapatılmasın; kapat/ertele butonları kullanılsın.
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // yok say
    }
}
