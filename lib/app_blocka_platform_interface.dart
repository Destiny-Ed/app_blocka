import 'package:app_blocka/app_blocka_method_channel.dart';
import 'package:app_blocka/app_usage_info_model.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class AppBlockaPlatform extends PlatformInterface {
  AppBlockaPlatform() : super(token: _token);

  static final Object _token = Object();
  static AppBlockaPlatform _instance = MethodChannelAppBlocka();
  static AppBlockaPlatform get instance => _instance;

  static set instance(AppBlockaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<bool> checkPermission() {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<List<AppInfo>> getAvailableApps() {
    throw UnimplementedError('getAvailableApps() has not been implemented.');
  }

  Future<bool> blockApp(String packageName) {
    throw UnimplementedError('blockApp() has not been implemented.');
  }

  Future<bool> unblockApp(String packageName) {
    throw UnimplementedError('unblockApp() has not been implemented.');
  }

  Future<bool> startBackgroundService() {
    throw UnimplementedError(
      'startBackgroundService() has not been implemented.',
    );
  }

  Future<bool> stopBackgroundService() {
    throw UnimplementedError(
      'stopBackgroundService() has not been implemented.',
    );
  }

  Future<void> setTimeLimit(String packageName, int minutes) {
    throw UnimplementedError('setTimeLimit() has not been implemented.');
  }

  Future<void> setSchedule(
    String packageName,
    List<Map<String, int>> schedules,
  ) {
    throw UnimplementedError('setSchedule() has not been implemented.');
  }

  Future<List<AppUsage>> getUsageStats() {
    throw UnimplementedError('getUsageStats() has not been implemented.');
  }

  Stream<String> get onAppBlocked {
    throw UnimplementedError('onAppBlocked has not been implemented.');
  }
}
