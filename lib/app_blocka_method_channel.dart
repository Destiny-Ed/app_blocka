import 'dart:async';

import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/services.dart';
import 'app_blocka_platform_interface.dart';

class MethodChannelAppBlocka extends AppBlockaPlatform {
  static const MethodChannel _channel = MethodChannel('app_blocka');
  static const EventChannel _eventChannel = EventChannel('app_blocka/events');

  Stream<String>? _onAppRestricted;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> initialize() async {
    await _channel.invokeMethod('initialize');
  }

  @override
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  @override
  Future<bool> checkPermission() async {
    final result = await _channel.invokeMethod<bool>('checkPermission');
    return result ?? false;
  }

  @override
  Future<bool> selectApps() async {
    try {
      final result = await _channel.invokeMethod<bool>('selectApps');
      return result ?? false;
    } catch (e) {
      throw Exception('Error selecting apps: $e');
    }
  }

  @override
  Future<List<AppInfo>> getAvailableApps() async {
    try {
      final apps = await _channel.invokeMethod<List<dynamic>>('getAvailableApps');
      return apps?.map((app) {
            final map = Map<String, dynamic>.from(app as Map);
            return AppInfo(
              packageName: map['packageName'] as String,
              name: map['name'] as String,
              isSystemApp: map['isSystemApp'] as bool,
              icon: map['icon'] as String?,
            );
          }).toList() ??
          [];
    } catch (e) {
      throw Exception('Error fetching apps: $e');
    }
  }

  @override
  Future<void> setTimeLimit(String packageName, int limitMinutes) async {
    await _channel.invokeMethod('setTimeLimit', {
      'packageName': packageName,
      'limitMinutes': limitMinutes,
    });
  }

  @override
  Future<void> setSchedule(String packageName, List<Map<String, int>> schedules) async {
    await _channel.invokeMethod('setSchedule', {
      'packageName': packageName,
      'schedules': schedules,
    });
  }

  @override
  Future<void> blockApp(String packageName) async {
    await _channel.invokeMethod('blockApp', {'packageName': packageName});
  }

  @override
  Future<void> unblockApp(String packageName) async {
    await _channel.invokeMethod('unblockApp', {'packageName': packageName});
  }

  @override
  Future<List<AppUsage>> getUsageStats() async {
    try {
      final stats = await _channel.invokeMethod<List<dynamic>>('getUsageStats');
      return stats?.map((stat) {
            final map = Map<String, dynamic>.from(stat as Map);
            return AppUsage(
              packageName: map['packageName'] as String,
              usageTime: map['usageTime'] as int,
              icon: map['icon'] as String?,
            );
          }).toList() ??
          [];
    } catch (e) {
      throw Exception('Error fetching usage stats: $e');
    }
  }

  @override
  Future<void> startBackgroundService() async {
    await _channel.invokeMethod('startBackgroundService');
  }

  @override
  Future<void> stopBackgroundService() async {
    await _channel.invokeMethod('stopBackgroundService');
  }

  @override
  Stream<String> get onAppRestricted {
    _onAppRestricted ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as String);
    return _onAppRestricted!;
  }
}