import 'package:app_blocka/app_blocka_platform_interface.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/services.dart';

class MethodChannelAppBlocka extends AppBlockaPlatform {
  final MethodChannel _channel = const MethodChannel('app_blocka');
  final EventChannel _eventChannel = const EventChannel('app_blocka/events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      print('Error initializing: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('checkPermission');
      return result ?? false;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final bool? result = await _channel.invokeMethod('requestPermission');
      return result ?? false;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  @override
  Future<List<AppInfo>> getAvailableApps() async {
    try {
      final List<dynamic>? apps = await _channel.invokeMethod(
        'getAvailableApps',
      );
      print('MethodChannel: Got apps: $apps');
      return apps
              ?.map(
                (dynamic app) => AppInfo(
                  packageName: app['packageName'] as String,
                  name: app['name'] as String,
                  icon: app['icon'] as String?,
                  isSystemApp: app['isSystemApp'] as bool,
                ),
              )
              .toList() ??
          [];
    } catch (e) {
      print('Error getting available apps: $e');
      rethrow;
    }
  }

  @override
  Future<bool> blockApp(String packageName) async {
    try {
      await _channel.invokeMethod('blockApp', {'packageName': packageName});
      return true;
    } catch (e) {
      print('Error blocking app: $e');
      return false;
    }
  }

  @override
  Future<bool> unblockApp(String packageName) async {
    try {
      await _channel.invokeMethod('unblockApp', {'packageName': packageName});
      return true;
    } catch (e) {
      print('Error unblocking app: $e');
      return false;
    }
  }

  @override
  Future<bool> startBackgroundService() async {
    try {
      await _channel.invokeMethod('startBackgroundService');
      return true;
    } catch (e) {
      print('Error starting background service: $e');
      return false;
    }
  }

  @override
  Future<bool> stopBackgroundService() async {
    try {
      await _channel.invokeMethod('stopBackgroundService');
      return true;
    } catch (e) {
      print('Error stopping background service: $e');
      return false;
    }
  }

  @override
  Future<void> setTimeLimit(String packageName, int minutes) async {
    try {
      await _channel.invokeMethod('setTimeLimit', {
        'packageName': packageName,
        'limitMinutes': minutes,
      });
    } catch (e) {
      print('Error setting time limit: $e');
      rethrow;
    }
  }

  @override
  Future<void> setSchedule(
    String packageName,
    List<Map<String, int>> schedules,
  ) async {
    try {
      await _channel.invokeMethod('setSchedule', {
        'packageName': packageName,
        'schedules': schedules,
      });
    } catch (e) {
      print('Error setting schedule: $e');
      rethrow;
    }
  }

  @override
  Future<List<AppUsage>> getUsageStats() async {
    try {
      final List<dynamic>? stats = await _channel.invokeMethod('getUsageStats');
      return stats
              ?.map(
                (dynamic stat) => AppUsage(
                  packageName: stat['packageName'] as String,
                  usageTime: stat['usageTime'] as int,
                  icon: stat['icon'] as String?,
                ),
              )
              .toList() ??
          [];
    } catch (e) {
      print('Error getting usage stats: $e');
      return [];
    }
  }

  @override
  Stream<String> get onAppBlocked => _eventChannel.receiveBroadcastStream().map(
    (dynamic event) => event as String,
  );
}
