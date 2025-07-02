import 'package:app_blocka/app_usage_info_model.dart';

import 'app_blocka_platform_interface.dart';

class AppBlocka {
  static final _platform = AppBlockaPlatform.instance;

  static Future<bool> requestPermission() => _platform.requestPermission();
  static Future<bool> checkPermission() => _platform.checkPermission();
  static Future<List<AppInfo>> getAvailableApps() => _platform.getAvailableApps();
  static Future<void> setTimeLimit(String packageName, int minutes) => _platform.setTimeLimit(packageName, minutes);
  static Future<void> setSchedule(String packageName, List<Map<String, int>> schedules) => _platform.setSchedule(packageName, schedules);
  static Future<void> blockApp(String packageName) => _platform.blockApp(packageName);
  static Future<void> unblockApp(String packageName) => _platform.unblockApp(packageName);
  static Future<List<AppUsage>> getUsageStats() => _platform.getUsageStats();
  static Future<void> startBackgroundService() => _platform.startBackgroundService();
  static Future<void> stopBackgroundService() => _platform.stopBackgroundService();
  static Stream<String> get onAppBlocked => _platform.onAppBlocked;
}