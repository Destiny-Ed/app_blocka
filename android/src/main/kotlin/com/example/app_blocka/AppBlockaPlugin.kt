package com.example.app_blocka

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream

class AppBlockaPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val selectedApps = mutableSetOf<String>() // To mimic iOS FamilyActivityPicker

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app_blocka")
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "app_blocka/events")
        channel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                // Initialize any services (e.g., background tasks)
                result.success(null)
            }
            "startBackgroundService" -> {
                // Implement background service if needed
                result.success(null)
            }
            "stopBackgroundService" -> {
                // Stop background service
                result.success(null)
            }
            "requestPermission" -> {
                // Android may not need permissions for app listing
                result.success(true)
            }
            "checkPermission" -> {
                result.success(true)
            }
            "presentAppPicker" -> {
                // Simulate iOS picker by accepting bundle IDs (or implement a custom picker)
                val bundleIds = call.argument<List<String>>("bundleIds") ?: emptyList()
                selectedApps.clear()
                selectedApps.addAll(bundleIds)
                result.success(true)
            }
            "getAvailableApps" -> {
                try {
                    val apps = getInstalledApps()
                    result.success(apps)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get apps: ${e.message}", null)
                }
            }
            "setTimeLimit" -> {
                val packageName = call.argument<String>("packageName")
                val limitMinutes = call.argument<Int>("limitMinutes")
                if (packageName != null && limitMinutes != null) {
                    // Implement time limit logic
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                }
            }
            "setSchedule" -> {
                val packageName = call.argument<String>("packageName")
                val schedules = call.argument<List<Map<String, Int>>>("schedules")
                if (packageName != null && schedules != null) {
                    // Implement schedule logic
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Invalid arguments", null)
                }
            }
            "blockApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    // Implement block app logic (e.g., using AccessibilityService)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Invalid package name", null)
                }
            }
            "unblockApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    // Implement unblock app logic
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Invalid package name", null)
                }
            }
            "getUsageStats" -> {
                try {
                    val stats = getAppUsageStats()
                    result.success(stats)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val packageManager = context.packageManager
        val apps = mutableListOf<Map<String, Any>>()
        val packages = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        for (pkg in packages) {
            // Only include selected apps if present, or all apps if empty
            if (selectedApps.isNotEmpty() && !selectedApps.contains(pkg.packageName)) {
                continue
            }
            val appInfo = mutableMapOf<String, Any>(
                "packageName" to pkg.packageName,
                "name" to (packageManager.getApplicationLabel(pkg).toString()),
                "isSystemApp" to ((pkg.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
            )
            // Add icon as base64 string (optional, matching iOS)
            getAppIcon(pkg.packageName)?.let { icon ->
                appInfo["icon"] = icon
            }
            apps.add(appInfo)
        }
        return apps
    }

    private fun getAppIcon(packageName: String): String? {
        return try {
            val packageManager = context.packageManager
            val drawable = packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            val byteArrayOutputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            Base64.encodeToString(byteArray, Base64.DEFAULT)
        } catch (e: Exception) {
            null // Return null if icon retrieval fails
        }
    }

    private fun getAppUsageStats(): List<Map<String, Any>> {
        // Placeholder: Implement usage stats with UsageStatsManager
        return selectedApps.map { packageName ->
            mutableMapOf<String, Any>(
                "packageName" to packageName,
                "usageTime" to 0,
                // Include icon if needed
                "icon" to (getAppIcon(packageName) ?: "")
            )
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Implement event stream for restricted apps if needed
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}