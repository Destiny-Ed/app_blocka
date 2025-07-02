package com.example.app_blocka

import android.app.Activity
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** AppBlockaPlugin */
class AppBlockaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_blocka")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "app_blocka/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                activity?.startActivity(intent)
                result.success(true)
            }
            "checkPermission" -> {
                val hasPermission = PermissionUtils.hasUsageStatsPermission(context)
                result.success(hasPermission)
            }
            "getAvailableApps" -> AppManager.getInstalledApps(context, result)
            "setTimeLimit" -> AppBlocker.setTimeLimit(context, call, result)
            "blockApp" -> AppBlocker.blockApp(context, call, result)
            "unblockApp" -> AppBlocker.unblockApp(context, call, result)
            "setSchedule" -> AppBlocker.setSchedule(context, call, result)
            "getUsageStats" -> AppUsageFetcher.getUsageStats(context, result)
            "startBackgroundService" -> {
                BackgroundServiceManager.start(context)
                result.success(true)
            }
            "stopBackgroundService" -> {
                BackgroundServiceManager.stop(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    companion object {
        fun sendEvent(message: String) {
            Handler(Looper.getMainLooper()).post {
                AppBlockaPlugin().eventSink?.success(message)
            }
        }
    }
}
