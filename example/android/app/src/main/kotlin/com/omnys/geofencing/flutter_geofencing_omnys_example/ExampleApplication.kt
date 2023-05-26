package com.omnys.geofencing.flutter_geofencing_omnys_example

import com.omnys.geofencing.flutter_geofencing_omnys.FlutterGeofencingOmnysPlugin
import io.flutter.app.FlutterApplication

class ExampleApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        FlutterGeofencingOmnysPlugin.applicationOnCreate(this)
    }
}