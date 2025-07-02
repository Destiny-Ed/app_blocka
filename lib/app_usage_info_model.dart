class AppInfo {
  final String packageName;
  final String name;
  final bool isSystemApp;
  final String? icon;

  AppInfo({required this.packageName, required this.name, required this.isSystemApp, this.icon});

  factory AppInfo.fromJson(Map<String, dynamic> json) => AppInfo(
    packageName: json['packageName'],
    name: json['name'],
    isSystemApp: json['isSystemApp'],
    icon: json['icon'],
  );

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'name': name,
    'isSystemApp': isSystemApp,
    'icon': icon,
  };
}

class AppUsage {
  final String packageName;
  final int usageTime;
  final String? icon;

  AppUsage({required this.packageName, required this.usageTime, this.icon});

  factory AppUsage.fromJson(Map<String, dynamic> json) => AppUsage(
    packageName: json['packageName'],
    usageTime: json['usageTime'],
    icon: json['icon'],
  );

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'usageTime': usageTime,
    'icon': icon,
  };
}