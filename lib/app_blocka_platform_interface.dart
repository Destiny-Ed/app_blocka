import 'package:app_blocka/app_time_range_model.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_blocka_method_channel.dart';

abstract class AppBlockaPlatform extends PlatformInterface {
  /// Constructs a AppBlockaPlatform.
  AppBlockaPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppBlockaPlatform _instance = MethodChannelAppBlocka();

  /// The default instance of [AppBlockaPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppBlocka].
  static AppBlockaPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppBlockaPlatform] when
  /// they register themselves.
  static set instance(AppBlockaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> startBackgroundService() {
    throw UnimplementedError('startBackgroundService() has not been implemented.');
  }

  Future<void> stopBackgroundService() {
    throw UnimplementedError('stopBackgroundService() has not been implemented.');
  }

  void setCustomBlockedUI(Widget Function(BuildContext, String) builder) {
    throw UnimplementedError('setCustomBlockedUI() has not been implemented.');
  }

  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<bool> checkPermission() {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  Future<List<AppInfo>> getAvailableApps() {
    throw UnimplementedError('getAvailableApps() has not been implemented.');
  }

  Future<void> setTimeLimit(String packageName, Duration limit) {
    throw UnimplementedError('setTimeLimit() has not been implemented.');
  }

  Future<void> setSchedule(String packageName, List<TimeRange> ranges) {
    throw UnimplementedError('setSchedule() has not been implemented.');
  }

  Future<void> blockApp(String packageName) {
    throw UnimplementedError('blockApp() has not been implemented.');
  }

  Future<void> unblockApp(String packageName) {
    throw UnimplementedError('unblockApp() has not been implemented.');
  }

  Future<List<AppUsage>> getUsageStats() {
    throw UnimplementedError('getUsageStats() has not been implemented.');
  }

  void startMonitoring(BuildContext context) {
    throw UnimplementedError('startMonitoring() has not been implemented.');
  }

  void stopMonitoring() {
    throw UnimplementedError('stopMonitoring() has not been implemented.');
  }

  void showBlockedUI(BuildContext context, String appName) {
    throw UnimplementedError('showBlockedUI() has not been implemented.');
  }
}
