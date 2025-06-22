import 'dart:developer';

import 'package:app_blocka/app_blocka_platform_interface.dart';
import 'package:app_blocka/app_usage_info_model.dart';

class AppBlocka {
  static final AppBlockaPlatform _platform = AppBlockaPlatform.instance;
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  Future<void> initialize() {
    return _platform.initialize();
  }

  Future<bool> requestPermission() {
    return _platform.requestPermission();
  }

  Future<bool> checkPermission() {
    return _platform.checkPermission();
  }

  Future<List<AppInfo>> getAvailableApps() async {
    try {
      return await _platform.getAvailableApps();
    } catch (e) {
      log('Failed to get available apps: $e');
      rethrow;
    }
  }

  Future<void> setTimeLimit(String packageName, int limitMinutes) {
    return _platform.setTimeLimit(packageName, limitMinutes);
  }

  Future<void> setSchedule(
    String packageName,
    List<Map<String, int>> schedules,
  ) {
    return _platform.setSchedule(packageName, schedules);
  }

  Future<void> blockApp(String packageName) {
    return _platform.blockApp(packageName);
  }

  Future<void> unblockApp(String packageName) {
    return _platform.unblockApp(packageName);
  }

  Future<List<AppUsage>> getUsageStats() async {
    try {
      return await _platform.getUsageStats();
    } catch (e) {
      log('Failed to get usage stats: $e');
      rethrow;
    }
  }

  Future<void> startBackgroundService() {
    return _platform.startBackgroundService();
  }

  Future<void> stopBackgroundService() {
    return _platform.stopBackgroundService();
  }

  Stream<String> get onAppBloced {
    return _platform.onAppBlocked;
  }
}
