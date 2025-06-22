
import 'dart:typed_data';

/// Model for an app's information, including icon.
class AppInfo {
  final String packageName;
  final String name;
  final bool isSystemApp;
  final Uint8List? icon;

  AppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
    this.icon,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      name: map['name'] as String,
      isSystemApp: map['isSystemApp'] as bool,
      icon: map['icon'] != null ? Uint8List.fromList((map['icon'] as List<dynamic>).cast<int>()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'name': name,
      'isSystemApp': isSystemApp,
      'icon': icon,
    };
  }
}


/// Model for app usage statistics, including icon.
class AppUsage {
  final String packageName;
  final Duration usageTime;
  final Uint8List? icon;

  AppUsage({
    required this.packageName,
    required this.usageTime,
    this.icon,
  });

  factory AppUsage.fromMap(Map<String, dynamic> map) {
    return AppUsage(
      packageName: map['packageName'] as String,
      usageTime: Duration(milliseconds: map['usageTime'] as int),
      icon: map['icon'] != null ? Uint8List.fromList((map['icon'] as List<dynamic>).cast<int>()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'usageTime': usageTime.inMilliseconds,
      'icon': icon,
    };
  }
}