import 'dart:async';

import 'package:app_blocka/app_time_range_model.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_blocka_platform_interface.dart';

/// An implementation of [AppBlockaPlatform] that uses method channels.
class MethodChannelAppBlocka extends AppBlockaPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('app_blocka');

  @visibleForTesting
  final eventChannel = EventChannel('app_blocka/events');

  static StreamSubscription? _subscription;
  static Widget Function(BuildContext, String)? _customBlockedUI;
  static final Map<String, Duration> _timeLimits = {};
  static final Map<String, List<TimeRange>> _schedules = {};

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLimits = prefs.getStringList('time_limits') ?? [];
    for (var limit in savedLimits) {
      final parts = limit.split(':');
      if (parts.length == 2) {
        _timeLimits[parts[0]] = Duration(minutes: int.parse(parts[1]));
      }
    }
    await methodChannel.invokeMethod('initialize');
  }

  @override
  Future<void> startBackgroundService() async {
    try {
      await methodChannel.invokeMethod('startBackgroundService');
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
  }

  @override
  Future<void> stopBackgroundService() async {
    try {
      await methodChannel.invokeMethod('stopBackgroundService');
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }
  }

  @override
  void setCustomBlockedUI(Widget Function(BuildContext, String) builder) {
    _customBlockedUI = builder;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await methodChannel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  @override
  Future<bool> checkPermission() async {
    try {
      return await methodChannel.invokeMethod('checkPermission');
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  @override
  Future<List<AppInfo>> getAvailableApps() async {
    try {
      final List<dynamic> apps = await methodChannel.invokeMethod(
        'getAvailableApps',
      );
      return apps.map((app) => AppInfo.fromMap(app)).toList();
    } catch (e) {
      debugPrint('Error fetching apps: $e');
      return [];
    }
  }

  @override
  Future<void> setTimeLimit(String packageName, Duration limit) async {
    _timeLimits[packageName] = limit;
    final prefs = await SharedPreferences.getInstance();
    final savedLimits = prefs.getStringList('time_limits') ?? [];
    savedLimits.removeWhere((l) => l.startsWith('$packageName:'));
    savedLimits.add('$packageName:${limit.inMinutes}');
    await prefs.setStringList('time_limits', savedLimits);
    try {
      await methodChannel.invokeMethod('setTimeLimit', {
        'packageName': packageName,
        'limitMinutes': limit.inMinutes,
      });
    } catch (e) {
      debugPrint('Error setting time limit: $e');
    }
  }

  @override
  Future<void> setSchedule(String packageName, List<TimeRange> ranges) async {
    _schedules[packageName] = ranges;
    try {
      await methodChannel.invokeMethod('setSchedule', {
        'packageName': packageName,
        'schedules':
            ranges
                .map(
                  (r) => {
                    'startHour': r.start.hour,
                    'startMinute': r.start.minute,
                    'endHour': r.end.hour,
                    'endMinute': r.end.minute,
                  },
                )
                .toList(),
      });
    } catch (e) {
      debugPrint('Error setting schedule: $e');
    }
  }

  @override
  Future<void> blockApp(String packageName) async {
    try {
      await methodChannel.invokeMethod('blockApp', {
        'packageName': packageName,
      });
    } catch (e) {
      debugPrint('Error blocking app: $e');
    }
  }

  @override
  Future<void> unblockApp(String packageName) async {
    try {
      await methodChannel.invokeMethod('unblockApp', {
        'packageName': packageName,
      });
    } catch (e) {
      debugPrint('Error unblocking app: $e');
    }
  }

  @override
  Future<List<AppUsage>> getUsageStats() async {
    try {
      final List<dynamic> stats = await methodChannel.invokeMethod(
        'getUsageStats',
      );
      return stats.map((s) => AppUsage.fromMap(s)).toList();
    } catch (e) {
      debugPrint('Error fetching usage stats: $e');
      return [];
    }
  }

  @override
  void startMonitoring(BuildContext context) {
    _subscription?.cancel();
    _subscription = eventChannel.receiveBroadcastStream().listen((event) {
      if (event is String && context.mounted) {
        showBlockedUI(context, event);
      }
    });
  }

  @override
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void showBlockedUI(BuildContext context, String appName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            onPopInvokedWithResult: (result, b) async => false,
            child:
                _customBlockedUI != null
                    ? _customBlockedUI!(context, appName)
                    : AlertDialog(
                      title: const Text('App Restricted'),
                      content: Text('Access to $appName is restricted.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            SystemNavigator.pop();
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
          ),
    );
  }
}
