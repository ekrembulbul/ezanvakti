package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.ParcelFileDescriptor
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class AlarmDeliveryTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private val roots = mutableListOf<String>()
    private var activity: AlarmRingActivity? = null

    private fun shell(command: String) {
        ParcelFileDescriptor.AutoCloseInputStream(instrumentation.uiAutomation.executeShellCommand(command))
            .bufferedReader().use { it.readText() }
    }

    @Before fun permissions() {
        shell("appops set " + context.packageName + " SCHEDULE_EXACT_ALARM allow")
        shell("pm grant " + context.packageName + " android.permission.POST_NOTIFICATIONS")
        assertTrue((context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms())
    }

    @After fun cleanup() {
        roots.forEach {
            AlarmScheduling.cancelAlarm(context, it)
            AlarmRingService.cancelForAlarm(context, it)
        }
        instrumentation.runOnMainSync { activity?.finish() }
    }

    private fun schedule(label: String): AlarmArgs {
        val root = "native-test-" + UUID.randomUUID()
        roots.add(root)
        val fire = System.currentTimeMillis() + 10_000
        val args = AlarmArgs(root + "#at" + fire, fire, label, "default", false, true, 5,
            alarmId = root, missionEnabled = true, mission = "qr", maxSnoozes = 2)
        AlarmScheduling.schedule(context, args)
        waitFor { AndroidMissionStore.missions(context).session(root)?.ringingScheduleId == args.id }
        return args
    }

    private fun waitFor(condition: () -> Boolean) {
        val until = System.currentTimeMillis() + 15_000
        while (!condition() && System.currentTimeMillis() < until) Thread.sleep(50)
        assertTrue("Native alarm transition did not complete", condition())
    }

    @Test fun alarmManagerDeliveryKeepsIdentityAndStopEvent() {
        val args = schedule("İş")
        val missions = AndroidMissionStore.missions(context)
        val fired = missions.session(args.alarmId)!!
        assertEquals(args.timeMillis, fired.firedAtMillis)
        assertTrue(fired.receivedAtMillis >= args.timeMillis)
        context.startService(Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_STOP
            args.writeTo(this)
        })
        waitFor {
            missions.session(args.alarmId)?.ringingScheduleId == null &&
                AlarmScheduling.allArgs(context).any { it.alarmId == args.alarmId && it.isWatchdog }
        }
        val event = missions.consume(args.alarmId).single()
        assertEquals(args.alarmId, event.alarmId)
        assertEquals(args.timeMillis, event.firedAt)
        assertFalse(event.chainStopped)
        assertTrue(AlarmScheduling.allArgs(context).any { it.alarmId == args.alarmId && it.isWatchdog })
    }

    @Test fun gatedRingScreenHidesNativeSnoozeAndOpensFlutter() {
        val args = schedule("QR görevli alarm")
        val main = instrumentation.addMonitor(MainActivity::class.java.name, null, false)
        activity = instrumentation.startActivitySync(Intent(context, AlarmRingActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            args.writeTo(this)
        }) as AlarmRingActivity
        instrumentation.runOnMainSync {
            assertEquals(args.label, activity!!.findViewById<TextView>(R.id.alarm_title).text.toString())
            assertEquals(android.view.View.GONE, activity!!.findViewById<android.view.View>(R.id.alarm_snooze).visibility)
            activity!!.findViewById<SlideToStopView>(R.id.alarm_dismiss).onCompleted!!.invoke()
        }
        val opened = instrumentation.waitForMonitorWithTimeout(main, 10_000)
        assertNotNull("Stopping a gated alarm must open Flutter", opened)
        instrumentation.removeMonitor(main)
    }
}
