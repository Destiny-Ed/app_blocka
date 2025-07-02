import 'package:app_blocka/app_usage_info_model.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'app_blocka_method_channel.dart';

abstract class AppBlockaPlatform extends PlatformInterface {
  AppBlockaPlatform() : super(token: _token);
  static final Object _token = Object();
  static AppBlockaPlatform _instance = MethodChannelAppBlocka();
  static AppBlockaPlatform get instance => _instance;
  static set instance(AppBlockaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> requestPermission();
  Future<bool> checkPermission();
  Future<List<AppInfo>> getAvailableApps();
  Future<void> setTimeLimit(String packageName, int minutes);
  Future<void> setSchedule(
    String packageName,
    List<Map<String, int>> schedules,
  );
  Future<void> blockApp(String packageName);
  Future<void> unblockApp(String packageName);
  Future<List<AppUsage>> getUsageStats();
  Future<void> startBackgroundService();
  Future<void> stopBackgroundService();
  Stream<String> get onAppBlocked;
}
