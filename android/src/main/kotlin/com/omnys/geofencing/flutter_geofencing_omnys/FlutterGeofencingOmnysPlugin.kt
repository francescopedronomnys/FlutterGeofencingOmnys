package com.omnys.geofencing.flutter_geofencing_omnys

/*
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

*/
/** FlutterGeofencingOmnysPlugin *//*

class FlutterGeofencingOmnysPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_geofencing_omnys")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
*/



import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray

class FlutterGeofencingOmnysPlugin : ActivityAware, FlutterPlugin, MethodCallHandler {
    private var mContext: Context? = null
    private var mActivity: Activity? = null
    private var beaconsClient: BeaconsClient? = null

    companion object {
        @JvmStatic
        private val TAG = "GeofencingPlugin"

        @JvmStatic
        val SHARED_PREFERENCES_KEY = "geofencing_plugin_cache"

        @JvmStatic
        val CALLBACK_HANDLE_KEY = "callback_handle"

        @JvmStatic
        val CALLBACK_DISPATCHER_HANDLE_KEY = "callback_dispatch_handler"

        @JvmStatic
        val PERSISTENT_GEOFENCES_KEY = "persistent_geofences"

        @JvmStatic
        val PERSISTENT_GEOFENCES_IDS = "persistent_geofences_ids"

        @JvmStatic
        private val sGeofenceCacheLock = Object()

        @JvmStatic
        fun reRegisterAfterReboot(context: Context) {/*
            TODO is this needed when using alt beacon library??
            synchronized(sGeofenceCacheLock) {
                var p = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
                var persistentGeofences = p.getStringSet(PERSISTENT_GEOFENCES_IDS, null)
                if (persistentGeofences == null) {
                    return
                }
                for (id in persistentGeofences) {
                    val gfJson = p.getString(getPersistentGeofenceKey(id), null)
                    if (gfJson == null) {
                        continue
                    }
                    val gfArgs = JSONArray(gfJson)
                    val list = ArrayList<Object>()
                    for (i in 0 until gfArgs.length()) {
                        list.add(gfArgs.get(i) as Object)
                    }
                    val geoClient = LocationServices.getGeofencingClient(context)
                    registerGeofence(context, geoClient, list, null, false)
                }
            }*/
        }

        @JvmStatic
        private fun registerGeofence(
            context: Context,
            beaconsClient: BeaconsClient,
            args: ArrayList<*>?,
            result: Result?,
            cache: Boolean
        ) {
            val callbackHandle = args!![0] as Long
            val regionDictionary: Map<String, *> = args[1] as Map<String, *>
            val region = GeofenceRegion.fromJson(regionDictionary)

            if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_DENIED) {
                val msg = "'registerGeofence' requires the ACCESS_FINE_LOCATION permission."
                Log.w(TAG, msg)
                result?.error(msg, null, null)
            }
            if (cache) {
                addGeofenceToCache(context, region.identifier, args)
            }
            beaconsClient.registerGeofence(region)
            Log.i(TAG, "Successfully added geofence")
            result?.success(true)
        }

        @JvmStatic
        private fun addGeofenceToCache(context: Context, id: String, args: ArrayList<*>) {
            synchronized(sGeofenceCacheLock) {
                val p = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
                val obj = JSONArray(args)
                val persistentGeofences = p.getStringSet(PERSISTENT_GEOFENCES_IDS, null).let {
                    if (it == null) {
                        return@let HashSet<String>()
                    } else {
                        return@let HashSet<String>(it)
                    }
                }

                persistentGeofences.add(id)
                context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE).edit()
                    .putStringSet(PERSISTENT_GEOFENCES_IDS, persistentGeofences)
                    .putString(getPersistentGeofenceKey(id), obj.toString()).apply()
            }
        }

        @JvmStatic
        fun getGeofenceFromCache(context: Context, id: String): JSONArray? {
            synchronized(sGeofenceCacheLock) {
                val p = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
                val geofenceJson = p.getString(getPersistentGeofenceKey(id), null) ?: return null
                return JSONArray(geofenceJson)
            }
        }

        @JvmStatic
        private fun initializeService(context: Context, args: ArrayList<*>?) {
            Log.d(TAG, "Initializing GeofencingService")
            val callbackHandle = args!![0] as Long
            context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE).edit()
                .putLong(CALLBACK_DISPATCHER_HANDLE_KEY, callbackHandle).apply()
        }


        @JvmStatic
        private fun removeGeofence(
            context: Context,
            beaconsClient: BeaconsClient,
            args: ArrayList<*>?,
            result: Result
        ) {
            val id = args!![0] as String
            val cachedGeofence = getGeofenceFromCache(context, id)
            if (cachedGeofence == null) {
                result.error("NOT_FOUND", null, null)
                return
            }
            val regionDictionary: Map<String, *> = cachedGeofence[1] as Map<String, *>
            val region = GeofenceRegion.fromJson(regionDictionary)
            beaconsClient.removeGeofence(region)
            removeGeofenceFromCache(context, id)
        }

        @JvmStatic
        private fun getRegisteredGeofenceIds(context: Context, result: Result) {
            synchronized(sGeofenceCacheLock) {
                val list = ArrayList<String>()
                var p = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
                var persistentGeofences = p.getStringSet(PERSISTENT_GEOFENCES_IDS, null)
                if (persistentGeofences != null && persistentGeofences.size > 0) {
                    for (id in persistentGeofences) {
                        list.add(id)
                    }
                }
                result.success(list)
            }
        }

        @JvmStatic
        private fun removeGeofenceFromCache(context: Context, id: String) {
            synchronized(sGeofenceCacheLock) {
                var p = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
                var persistentGeofences = p.getStringSet(PERSISTENT_GEOFENCES_IDS, null)
                if (persistentGeofences == null) {
                    return
                }
                persistentGeofences = HashSet<String>(persistentGeofences)
                persistentGeofences.remove(id)
                p.edit().remove(getPersistentGeofenceKey(id))
                    .putStringSet(PERSISTENT_GEOFENCES_IDS, persistentGeofences).apply()
            }
        }

        @JvmStatic
        private fun getPersistentGeofenceKey(id: String): String {
            return "persistent_geofence/" + id
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mContext = binding.applicationContext
        beaconsClient = BeaconsClient().also {
            it.init(binding.applicationContext)
        }
        val channel = MethodChannel(binding.binaryMessenger, "plugins.flutter.io/geofencing_plugin")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        mContext = null
        beaconsClient = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        mActivity = binding.activity
    }

    override fun onDetachedFromActivity() {
        mActivity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        mActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        mActivity = binding.activity
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val args = call.arguments<ArrayList<*>>()
        when (call.method) {
            "GeofencingPlugin.initializeService" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    mActivity?.requestPermissions(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_BACKGROUND_LOCATION
                        ), 12312
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    mActivity?.requestPermissions(
                        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 12312
                    )
                }
                initializeService(mContext!!, args)
                result.success(true)
            }

            "GeofencingPlugin.registerGeofence" -> registerGeofence(
                mContext!!, beaconsClient!!, args, result, true
            )

            "GeofencingPlugin.removeGeofence" -> removeGeofence(
                mContext!!, beaconsClient!!, args, result
            )

            "GeofencingPlugin.getRegisteredGeofenceIds" -> getRegisteredGeofenceIds(
                mContext!!, result
            )

            else -> result.notImplemented()
        }
    }
}