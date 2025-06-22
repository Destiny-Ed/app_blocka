
# app_blocka

A Flutter plugin to limit app usage and manage screen time on Android and iOS. Features include time-based restrictions, scheduled blocking, usage tracking, and a background service for persistent monitoring.

## Features

- **Time-Based Restrictions**: Set daily time limits for apps.  
- **Scheduled Blocking**: Block apps during specific time ranges.  
- **App Listing**: Fetch installed and system apps with names and icons.  
- **Usage Tracking**: Monitor app usage with statistics and icons.  
- **Background Service**: Persistent monitoring even when the app is in the background.  
- **Customizable Blocked UI**: Display a custom UI when apps are restricted.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  app_blocka: ^0.2.0
```

## Usage

### Initialize:

```dart
await AppBlocka.initialize();
await AppBlocka.startBackgroundService();
```

### Request Permissions:

```dart
bool granted = await AppBlocka.requestPermission();
```

### Fetch Apps:

```dart
List<AppInfo> apps = await AppBlocka.getAvailableApps();
```

### Set Time Limit:

```dart
await AppBlocka.setTimeLimit('com.example.app', Duration(minutes: 30));
```

### Set Schedule:

```dart
await AppBlocka.setSchedule('com.example.app', [
  TimeRange(start: TimeOfDay(hour: 22, minute: 0), end: TimeOfDay(hour: 6, minute: 0)),
]);
```

### Get Usage Stats:

```dart
List<AppUsage> stats = await AppBlocka.getUsageStats();
```

### Custom Blocked UI:

```dart
AppBlocka.setCustomBlockedUI((context, appName) => AlertDialog(
  title: Text('Restricted'),
  content: Text('\$appName is blocked.'),
  actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
  ],
));
```

### Start Monitoring:

```dart
AppBlocka.startMonitoring(context);
```

## Platform Setup

### iOS

- Open `ios/Runner.xcworkspace` in Xcode.  
- Enable Family Controls, Notifications, and Background Modes (Background Processing).  
- Add a Device Activity Monitor Extension.  
- Test via TestFlight due to Family Controls restrictions.

```plist
<key>NSUserNotificationsUsageDescription</key>
  <string>Allow notifications for app restriction alerts.</string>
<key>BGTaskSchedulerPermittedIdentifiers</key>
  <array>
      <string>com.example.app_blocka.backgroundMonitoring</string>
  </array>
<!-- Add Family Controls entitlement via Xcode -->
```

### Android

Declare permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions"/>
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

- Test on a physical device for overlay and usage stats support.

## Notes

- **iOS Limitations**: Usage stats are limited; test on real devices via TestFlight.  
- **Android Limitations**: Usage stats are daily; overlays require manual permission.  
- **Compliance**: Ensure compliance with App Store and Play Store policies.  
- **Performance**: Cache icons to reduce platform channel overhead.
