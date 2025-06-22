package com.example.app_blocka

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.PixelFormat
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.util.Calendar

class AppBlockaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var context: Context
  private lateinit var channel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private val scope = CoroutineScope(Dispatchers.Main)
  private val restrictedApps = mutableSetOf<String>()
  private val timeLimits = mutableMapOf<String, Int>() // Minutes
  private val schedules = mutableMapOf<String, List<Map<String, Int>>>()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "app_blocka")
    eventChannel = EventChannel(binding.binaryMessenger, "app_blocka/events")
    channel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        context.registerReceiver(
          TimeLimitReceiver(this),
          IntentFilter("com.example.app_blocka.TIME_LIMIT_EXCEEDED")
        )
        context.registerReceiver(
          TimeLimitReceiver(this),
          IntentFilter("com.example.app_blocka.BLOCK_APP")
        )
        context.registerReceiver(
          TimeLimitReceiver(this),
          IntentFilter("com.example.app_blocka.UNBLOCK_APP")
        )
        result(null)
      }
      "startBackgroundService" -> {
        val intent = Intent(context, AppBlockaService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(intent)
        } else {
          context.startService(intent)
        }
        result(null)
      }
      "stopBackgroundService" -> {
        context.stopService(Intent(context, AppBlockaService::class.java))
        result(null)
      }
      "requestPermission" -> {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          if (!Settings.canDrawOverlays(context)) {
            val overlayIntent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            overlayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(overlayIntent)
          }
        }
        result.success(true)
      }
      "checkPermission" -> {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
          appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
          )
        } else {
          @Suppress("DEPRECATION")
          appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
          )
        }
        val overlayGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
        result.success(mode == AppOpsManager.MODE_ALLOWED && overlayGranted)
      }
      "getAvailableApps" -> {
        val apps = getAvailableApps()
        result.success(apps)
      }
      "setTimeLimit" -> {
        val packageName = call.argument<String>("packageName")
        val limitMinutes = call.argument<Int>("limitMinutes")
        if (packageName != null && limitMinutes != null) {
          timeLimits[packageName] = limitMinutes
          scheduleTimeLimitCheck(packageName, limitMinutes)
          result.success(null)
        } else {
          result.error("INVALID_ARGS", "Invalid arguments", null)
        }
      }
      "setSchedule" -> {
        val packageName = call.argument<String>("packageName")
        val scheduleMaps = call.argument<List<Map<String, Int>>>("schedules")
        if (packageName != null && scheduleMaps != null) {
          schedules[packageName] = scheduleMaps
          scheduleRestrictionsForPackage(packageName)
          result.success(null)
        } else {
          result.error("INVALID_ARGS", "Invalid arguments", null)
        }
      }
      "blockApp" -> {
        val packageName = call.argument<String>("packageName")
        if (packageName != null) {
          restrictedApps.add(packageName)
          result.success(null)
        } else {
          result.error("INVALID_ARGS", "Invalid package name", null)
        }
      }
      "unblockApp" -> {
        val packageName = call.argument<String>("packageName")
        if (packageName != null) {
          restrictedApps.remove(packageName)
          result.success(null)
        } else {
          result.error("INVALID_ARGS", "Invalid package name", null)
        }
      }
      "getUsageStats" -> {
        val stats = getUsageStats()
        result.success(stats)
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
    scope.cancel()
  }

  private fun getAvailableApps(): List<Map<String, Any?>> {
    val pm = context.packageManager
    val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
    return apps.map { app ->
      val iconData = getAppIcon(app.packageName)
      mapOf(
        "packageName" to app.packageName,
        "name" to (pm.getApplicationLabel(app) as String),
        "isSystemApp" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
        "icon" to iconData?.toList()
      )
    }
  }

  private fun getAppIcon(packageName: String): ByteArray? {
    return try {
      val pm = context.packageManager
      val drawable = pm.getApplicationIcon(packageName)
      val bitmap = drawableToBitmap(drawable, 48)
      val stream = ByteArrayOutputStream()
      bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
      stream.toByteArray()
    } catch (e: Exception) {
      null
    }
  }

  private fun drawableToBitmap(drawable: Drawable, size: Int): Bitmap {
    if (drawable is BitmapDrawable && drawable.bitmap != null) {
      return Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
    }
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)
    return bitmap
  }

  private fun getTopApp(): String? {
    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val time = System.currentTimeMillis()
    val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 60, time)
    return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
  }

  private fun getUsageStats(): List<Map<String, Any?>> {
    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val time = System.currentTimeMillis()
    val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 24 * 60 * 60 * 1000, time)
    return restrictedApps.map { pkg ->
      val stat = stats.find { it.packageName == pkg }
      val iconData = getAppIcon(pkg)
      mapOf(
        "packageName" to pkg,
        "usageTime" to (stat?.totalTimeInForeground ?: 0),
        "icon" to iconData?.toList()
      )
    }
  }

  private fun scheduleTimeLimitCheck(packageName: String, limitMinutes: Int) {
    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    val time = System.currentTimeMillis()
    val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 24 * 60 * 60 * 1000, time)
    val usage = stats.find { it.packageName == packageName }?.totalTimeInForeground ?: 0
    if (usage / 1000 / 60 >= limitMinutes) {
      restrictedApps.add(packageName)
      notifyTimeLimitExceeded(packageName)
    } else {
      val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
      val intent = Intent("com.example.app_blocka.TIME_LIMIT_EXCEEDED").apply {
        putExtra("packageName", packageName)
      }
      val pendingIntent = PendingIntent.getBroadcast(
        context,
        packageName.hashCode(),
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      val triggerTime = time + ((limitMinutes * 60 * 1000) - usage)
      alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
    }
  }

  private fun scheduleRestrictionsForPackage(packageName: String) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    schedules[packageName]?.forEach { schedule ->
      val startHour = schedule["startHour"] ?: return@forEach
      val startMinute = schedule["startMinute"] ?: return@forEach
      val endHour = schedule["endHour"] ?: return@forEach
      val endMinute = schedule["endMinute"] ?: return@forEach

      val startIntent = Intent("com.example.app_blocka.BLOCK_APP").apply {
        putExtra("packageName", packageName)
      }
      val startPendingIntent = PendingIntent.getBroadcast(
        context,
        "${packageName}_start".hashCode(),
        startIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )

      val endIntent = Intent("com.example.app_blocka.UNBLOCK_APP").apply {
        putExtra("packageName", packageName)
      }
      val endPendingIntent = PendingIntent.getBroadcast(
        context,
        "${packageName}_end".hashCode(),
        endIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )

      val startCalendar = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, startHour)
        set(Calendar.MINUTE, startMinute)
        set(Calendar.SECOND, 0)
        if (timeInMillis < System.currentTimeMillis()) {
          add(Calendar.DAY_OF_MONTH, 1)
        }
      }
      val endCalendar = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, endHour)
        set(Calendar.MINUTE, endMinute)
        set(Calendar.SECOND, 0)
        if (timeInMillis < startCalendar.timeInMillis) {
          add(Calendar.DAY_OF_MONTH, 1)
        }
      }

      alarmManager.setRepeating(
        AlarmManager.RTC_WAKEUP,
        startCalendar.timeInMillis,
        AlarmManager.INTERVAL_DAY,
        startPendingIntent
      )
      alarmManager.setRepeating(
        AlarmManager.RTC_WAKEUP,
        endCalendar.timeInMillis,
        AlarmManager.INTERVAL_DAY,
        endPendingIntent
      )
    }
  }

  private fun notifyTimeLimitExceeded(packageName: String) {
    val notification = NotificationCompat.Builder(context, "app_blocka_channel")
      .setSmallIcon(android.R.drawable.ic_dialog_alert)
      .setContentTitle("Time Limit Exceeded")
      .setContentText("$packageName has reached its time limit.")
      .setPriority(NotificationCompat.PRIORITY_DEFAULT)
      .build()
    NotificationManagerCompat.from(context).notify(packageName.hashCode(), notification)
  }

  fun checkAndBlockApps() {
    val topApp = getTopApp()
    if (topApp != null && restrictedApps.contains(topApp)) {
      eventSink?.success(topApp)
      startBlockService()
    }
    for (pkg in timeLimits.keys) {
      scheduleTimeLimitCheck(pkg, timeLimits[pkg] ?: 0)
    }
  }

  private fun startBlockService() {
    val intent = Intent(context, AppBlockaService::class.java)
    context.startService(intent)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    scope.cancel()
    context.unregisterReceiver(TimeLimitReceiver(this))
  }
}

class TimeLimitReceiver(private val plugin: AppBlockaPlugin) : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      "com.example.app_blocka.TIME_LIMIT_EXCEEDED" -> {
        val packageName = intent.getStringExtra("packageName") ?: return
        plugin.restrictedApps.add(packageName)
        plugin.notifyTimeLimitExceeded(packageName)
      }
      "com.example.app_blocka.BLOCK_APP" -> {
        val packageName = intent.getStringExtra("packageName") ?: return
        plugin.restrictedApps.add(packageName)
      }
      "com.example.app_blocka.UNBLOCK_APP" -> {
        val packageName = intent.getStringExtra("packageName") ?: return
        plugin.restrictedApps.remove(packageName)
      }
    }
  }
}

class AppBlockaService : Service() {
  private val handler = Handler(Looper.getMainLooper())
  private lateinit var context: Context
  private val scope = CoroutineScope(Dispatchers.Main)

  override fun onCreate() {
    super.onCreate()
    context = this
    startForeground(1, createNotification())
    startMonitoring()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  private fun startMonitoring() {
    scope.launch {
      while (true) {
        (context as? AppBlockaPlugin)?.checkAndBlockApps()
        delay(1000)
      }
    }
  }

  private fun createNotification(): Notification {
    val channelId = "app_blocka_service_channel"
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        channelId,
        "App Blocka Service",
        NotificationManager.IMPORTANCE_LOW
      )
      NotificationManagerCompat.from(this).createNotificationChannel(channel)
    }
    return NotificationCompat.Builder(this, channelId)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setContentTitle("App Blocka Running")
      .setContentText("Monitoring app usage in the background")
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }

  private fun showOverlay() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
      return
    }

    val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    val layoutParams = WindowManager.LayoutParams(
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.MATCH_PARENT,
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
      else
        @Suppress("DEPRECATION")
        WindowManager.LayoutParams.TYPE_PHONE,
      WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
      PixelFormat.TRANSLUCENT
    )

    val view = {
      setBackgroundColor(Color.BLACK)
      alpha = 0.8f
    }

    windowManager.addView(view, layoutParams)
    handler.postDelayed({
      view.windowManager.removeView(view)
    }, 3000)
  }

  override fun onDestroy() {
    super.onDestroy()
    scope.cancel()
  }
}