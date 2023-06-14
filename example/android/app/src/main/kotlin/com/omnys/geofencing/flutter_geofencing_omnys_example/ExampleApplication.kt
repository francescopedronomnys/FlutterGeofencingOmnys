package com.omnys.geofencing.flutter_geofencing_omnys_example

import android.util.Log
import com.omnys.geofencing.flutter_geofencing_omnys.FlutterGeofencingOmnysPlugin
import com.omnys.geofencing.flutter_geofencing_omnys.NativeRegionCallback
import io.flutter.app.FlutterApplication
import org.altbeacon.beacon.MonitorNotifier
import org.altbeacon.beacon.Region

class ExampleApplication : FlutterApplication(), NativeRegionCallback {
    override fun onCreate() {
        super.onCreate()
        FlutterGeofencingOmnysPlugin.applicationOnCreate(this, callback = this)
    }

    override fun didEnterRegion(region: Region) {
        Log.d(
            ExampleApplication::class.simpleName,
            "Native didEnterRegion registered for region ${region.uniqueId}"
        )
    }

    override fun didExitRegion(region: Region) {
        Log.d(
            ExampleApplication::class.simpleName,
            "Native didExitRegion registered for region ${region.uniqueId}"
        )
    }

    override fun didDetermineStateForRegion(state: Int, region: Region) {
        Log.d(
            ExampleApplication::class.simpleName,
            "Native didDetermineStateForRegion registered for region ${region.uniqueId} with state ${if (state == MonitorNotifier.INSIDE) "INSIDE" else "OUTSIDE"}"
        )
    }
}