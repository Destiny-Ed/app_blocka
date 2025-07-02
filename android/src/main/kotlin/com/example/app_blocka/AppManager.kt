package com.example.app_blocka

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Base64
import java.io.ByteArrayOutputStream

object AppManager {
    fun getInstalledApps(context: Context, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val pm = context.packageManager
            val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA).map {
                val appName = pm.getApplicationLabel(it).toString()
                val isSystemApp = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val icon = getAppIconBase64(pm.getApplicationIcon(it))
                mapOf(
                    "packageName" to it.packageName,
                    "name" to appName,
                    "isSystemApp" to isSystemApp,
                    "icon" to icon
                )
            }
            result.success(apps)
        } catch (e: Exception) {
            result.error("APP_ERROR", e.localizedMessage, null)
        }
    }

    private fun getAppIconBase64(drawable: android.graphics.drawable.Drawable): String {
        val bitmap = Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }
}