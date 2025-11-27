// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.omnys.geofencing.flutter_geofencing_omnys

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Parcelable
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor.DartCallback
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.view.FlutterCallbackInformation
import org.altbeacon.beacon.Region
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean

class GeofencingService : MethodCallHandler {
    private val queue = ArrayDeque<List<Any>>()
    private lateinit var backgroundChannel: MethodChannel
    private lateinit var applicationContext: Context

    // Modern functional interface for plugin registration
    fun interface PluginRegistrantCallback {
        fun registerWith(flutterEngine: FlutterEngine)
    }

    companion object {
        private var INSTANCE: GeofencingService? = null

        private fun ensureInstance(context: Context): GeofencingService {
            synchronized(sServiceStarted) {
                return INSTANCE ?: let {
                    GeofencingService().also {
                        INSTANCE = it
                        it.onCreate(context)
                    }
                }
            }
        }

        @JvmStatic
        private val TAG = "GeofencingService"

        @JvmStatic
        private var sBackgroundFlutterEngine: FlutterEngine? = null

        @JvmStatic
        private val sServiceStarted = AtomicBoolean(false)

        @JvmStatic
        private var sPluginRegistrantCallback: PluginRegistrantCallback? = null

        @JvmStatic
        fun setPluginRegistrant(callback: PluginRegistrantCallback) {
            sPluginRegistrantCallback = callback
        }

        @JvmStatic
        fun enqueueWork(applicationContext: Context, work: Intent) {
            ensureInstance(applicationContext).onHandleWork(work)
        }

        @JvmStatic
        fun createIntent(context: Context, region: Region, eventType: EventType): Intent {
            val intent = Intent(context, GeofencingService::class.java)
            intent.putExtra("region", region as Parcelable)
            intent.putExtra("eventType", eventType)
            return intent
        }

        @JvmStatic
        fun parseIntentRegion(intent: Intent): Region? {
            return intent.getParcelableExtra("region")
        }

        @JvmStatic
        fun parseIntentEventType(intent: Intent): EventType? {
            return intent.getSerializableExtra("eventType") as EventType?
        }
    }

    private fun startGeofencingService(context: Context) {
        synchronized(sServiceStarted) {
            applicationContext = context
            if (sBackgroundFlutterEngine == null) {
                val flutterLoader = FlutterInjector.instance().flutterLoader()

                if (!flutterLoader.initialized()) {
                    flutterLoader.startInitialization(context)
                }
                flutterLoader.ensureInitializationComplete(context, null)

                sBackgroundFlutterEngine = FlutterEngine(context)

                val callbackHandle = context.getSharedPreferences(
                    FlutterGeofencingOmnysPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE
                )
                    .getLong(FlutterGeofencingOmnysPlugin.CALLBACK_DISPATCHER_HANDLE_KEY, 0)
                if (callbackHandle == 0L) {
                    Log.e(TAG, "Fatal: no callback registered")
                    return
                }

                val callbackInfo =
                    FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
                if (callbackInfo == null) {
                    Log.e(TAG, "Fatal: failed to find callback")
                    return
                }
                Log.i(TAG, "Starting GeofencingService...")

                val args = DartCallback(
                    context.assets,
                    flutterLoader.findAppBundlePath(),
                    callbackInfo
                )
                sBackgroundFlutterEngine!!.dartExecutor.executeDartCallback(args)

                // FIXED: Pass the engine directly to the callback
                sPluginRegistrantCallback?.registerWith(sBackgroundFlutterEngine!!)
            }
        }
        backgroundChannel = MethodChannel(
            sBackgroundFlutterEngine!!.dartExecutor.binaryMessenger,
            "plugins.flutter.io/geofencing_plugin_background"
        )
        backgroundChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "GeofencingService.initialized" -> {
                synchronized(sServiceStarted) {
                    while (!queue.isEmpty()) {
                        backgroundChannel.invokeMethod("", queue.remove())
                    }
                    sServiceStarted.set(true)
                }
            }

            else -> result.notImplemented()
        }
        result.success(null)
    }

    fun onCreate(context: Context) {
        startGeofencingService(context)
    }

    fun onHandleWork(intent: Intent) {
        val region = parseIntentRegion(intent);
        val eventType = parseIntentEventType(intent)
        if (region == null || eventType == null) {
            Log.e(TAG, "Geofencing error: region $region, eventType $eventType")
            return
        }

        val geofenceFromCache =
            FlutterGeofencingOmnysPlugin.getGeofenceFromCache(applicationContext, region.uniqueId)
        if (geofenceFromCache == null) {
            Log.e(TAG, "Geofencing error: no geofence found in case for ${region.uniqueId}");
            return
        }
        val callbackHandle = geofenceFromCache[0] as Long

        val geofenceUpdateList =
            listOf(callbackHandle, listOf(region.uniqueId), eventType.dartValue)

        synchronized(sServiceStarted) {
            if (!sServiceStarted.get()) {
                // Queue up geofencing events while background isolate is starting
                queue.add(geofenceUpdateList)
            } else {
                Handler(applicationContext.mainLooper).post {
                    backgroundChannel.invokeMethod(
                        "", geofenceUpdateList
                    )
                }
            }
        }
    }
}