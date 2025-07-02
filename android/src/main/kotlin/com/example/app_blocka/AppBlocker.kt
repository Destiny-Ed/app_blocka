package com.example.app_blocka

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object AppBlocker {
    private val blockedApps = mutableSetOf<String>()
    private val timeLimits = mutableMapOf<String, Int>()

    fun setTimeLimit(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName") ?: return result.error("INVALID_ARGS", "Missing packageName", null)
        val limit = call.argument<Int>("limitMinutes") ?: 0
        timeLimits[packageName] = limit
        result.success(null)
    }

    fun blockApp(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName") ?: return result.error("INVALID_ARGS", "Missing packageName", null)
        blockedApps.add(packageName)
        result.success(null)
    }

    fun unblockApp(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName") ?: return result.error("INVALID_ARGS", "Missing packageName", null)
        blockedApps.remove(packageName)
        result.success(null)
    }

    fun setSchedule(context: Context, call: MethodCall, result: MethodChannel.Result) {
        // Simulate for now
        result.success(null)
    }
}