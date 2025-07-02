package com.example.app_blocka

import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import java.util.*

object AppUsageFetcher {
    fun getUsageStats(context: Context, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                now - 1000 * 3600 * 24,
                now
            )

            val usageList = stats.map {
                mapOf(
                    "packageName" to it.packageName,
                    "usageTime" to it.totalTimeInForeground / 1000L,
                    "icon" to null
                )
            }

            result.success(usageList)
        } catch (e: Exception) {
            Log.e("AppUsageFetcher", "Failed to fetch stats", e)
            result.error("USAGE_ERROR", e.message, null)
        }
    }
}