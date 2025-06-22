
import 'dart:typed_data';

/// Model for an app's information, including icon.
class AppInfo {
  final String packageName;
  final String name;
  final bool isSystemApp;
  final String? icon; // Base64-encoded string

  AppInfo({
    required this.packageName,
    required this.name,
    required this.isSystemApp,
    this.icon,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      packageName: json['packageName'] as String,
      name: json['name'] as String,
      isSystemApp: json['isSystemApp'] as bool,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
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
  final int usageTime;
  final String? icon; // Base64-encoded string

  AppUsage({
    required this.packageName,
    required this.usageTime,
    this.icon,
  });

  factory AppUsage.fromJson(Map<String, dynamic> json) {
    return AppUsage(
      packageName: json['packageName'] as String,
      usageTime: json['usageTime'] as int,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'usageTime': usageTime,
      'icon': icon,
    };
  }
}