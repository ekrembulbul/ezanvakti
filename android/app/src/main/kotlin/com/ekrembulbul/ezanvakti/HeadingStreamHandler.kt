package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.Surface
import io.flutter.plugin.common.EventChannel

/** Cihazın pusula yönünü Flutter'a akıtır (iOS HeadingStreamHandler.swift'in
 *  karşılığı). Dart koordinat verirse manyetik sapma eklenir ve gerçek kuzey
 *  döner; vermezse manyetik kuzey. */
class HeadingStreamHandler(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
    companion object { const val CHANNEL = "com.ekrembulbul.ezanvakti/heading" }

    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var declination: Double? = null
    private var lastEmitted: Double? = null
    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null) {
            events.error("heading_unavailable", "No compass sensor", null)
            return
        }
        val args = arguments as? Map<*, *>
        val lat = (args?.get("latitude") as? Number)?.toFloat()
        val lon = (args?.get("longitude") as? Number)?.toFloat()
        declination = if (lat != null && lon != null) {
            GeomagneticField(lat, lon, 0f, System.currentTimeMillis()).declination.toDouble()
        } else null
        sink = events
        lastEmitted = null
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        // Ekran dönmüşse eksenler ekrana göre çevrilir: yön her zaman
        // ekranın üst kenarının baktığı yön olsun.
        val (axisX, axisY) = when (displayRotation()) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotation, axisX, axisY, remapped)
        SensorManager.getOrientation(remapped, orientation)
        val magnetic = HeadingMath.normalize(Math.toDegrees(orientation[0].toDouble()))
        val degrees = declination?.let { HeadingMath.trueHeading(magnetic, it) } ?: magnetic
        if (!HeadingMath.shouldEmit(lastEmitted, degrees)) return
        lastEmitted = degrees
        val estimate = if (event.values.size > 4) event.values[4] else null
        out.success(mapOf(
            "degrees" to degrees,
            "accuracy" to HeadingMath.accuracyDegrees(estimate, event.accuracy),
        ))
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) activity.display?.rotation ?: Surface.ROTATION_0
        else activity.windowManager.defaultDisplay.rotation
}
