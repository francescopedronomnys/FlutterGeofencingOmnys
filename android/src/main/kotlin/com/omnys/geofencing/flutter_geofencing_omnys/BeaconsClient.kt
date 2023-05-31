package com.omnys.geofencing.flutter_geofencing_omnys

import android.content.Context
import org.altbeacon.beacon.BeaconManager
import org.altbeacon.beacon.BeaconParser
import org.altbeacon.beacon.MonitorNotifier
import org.altbeacon.beacon.Region

class BeaconsClient : MonitorNotifier {
    private lateinit var context: Context
    private lateinit var beaconManager: BeaconManager

    fun init(application: Context) {
        context = application
        //BeaconManager.setDebug(true)
        beaconManager = BeaconManager.getInstanceForApplication(application).also { beaconManager ->

            // Add parsing support for iBeacon
            // https://beaconlayout.wordpress.com/
            beaconManager.beaconParsers.clear()
            beaconManager.beaconParsers.add(BeaconParser().setBeaconLayout("m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24"))
            beaconManager.addMonitorNotifier(this)
        }
    }

    fun registerGeofence(region: GeofenceRegion) {
        beaconManager.startMonitoring(region.frameworkValue())
    }

    fun removeGeofence(region: GeofenceRegion) {
        beaconManager.stopMonitoring(region.frameworkValue())
    }

    override fun didEnterRegion(region: Region) {
        GeofencingService.enqueueWork(
            context,
            GeofencingService.createIntent(context, region, EventType.ENTER)
        )
    }

    override fun didExitRegion(region: Region) {
        GeofencingService.enqueueWork(
            context,
            GeofencingService.createIntent(context, region, EventType.EXIT)
        )
    }

    override fun didDetermineStateForRegion(state: Int, region: Region) {

    }

    companion object {
        private const val Tag = "beacons client"

    }
}