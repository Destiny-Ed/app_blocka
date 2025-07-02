package com.example.app_blocka

import android.content.Context
import android.content.Intent

object BackgroundServiceManager {
    fun start(context: Context) {
        val intent = Intent(context, AppBlockAccessibilityService::class.java)
        context.startService(intent)
    }

    fun stop(context: Context) {
        val intent = Intent(context, AppBlockAccessibilityService::class.java)
        context.stopService(intent)
    }
}