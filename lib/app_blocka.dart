import 'package:app_blocka/app_time_range_model.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/widgets.dart';

import 'app_blocka_platform_interface.dart';

/// AppBlocka plugin for blocking apps and managing screen time.
class AppBlocka {
  static AppBlockaPlatform get _platform => AppBlockaPlatform.instance;

  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  static Future<void> initialize() => _platform.initialize();

  static Future<void> startBackgroundService() =>
      _platform.startBackgroundService();

  static Future<void> stopBackgroundService() =>
      _platform.stopBackgroundService();

  static void setCustomBlockedUI(
    Widget Function(BuildContext, String) builder,
  ) => _platform.setCustomBlockedUI(builder);

  static Future<bool> requestPermission() => _platform.requestPermission();

  static Future<bool> checkPermission() => _platform.checkPermission();

  static Future<List<AppInfo>> getAvailableApps() =>
      _platform.getAvailableApps();

  static Future<void> setTimeLimit(String packageName, Duration limit) =>
      _platform.setTimeLimit(packageName, limit);

  static Future<void> setSchedule(String packageName, List<TimeRange> ranges) =>
      _platform.setSchedule(packageName, ranges);

  static Future<void> blockApp(String packageName) =>
      _platform.blockApp(packageName);

  static Future<void> unblockApp(String packageName) =>
      _platform.unblockApp(packageName);

  static Future<List<AppUsage>> getUsageStats() => _platform.getUsageStats();

  static void startMonitoring(BuildContext context) =>
      _platform.startMonitoring(context);

  static void stopMonitoring() => _platform.stopMonitoring();
}
