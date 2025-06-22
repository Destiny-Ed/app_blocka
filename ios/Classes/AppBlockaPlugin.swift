import Flutter
import UIKit
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import BackgroundTasks
import SwiftUI

public class AppBlockaPlugin: NSObject, FlutterPlugin {
    private let store = ManagedSettingsStore()
    private var restrictedApps: Set<String> = [] // Store bundle IDs
    private var selectedApps: [String: Application] = [:] // Store bundle ID to Application
    private var timeLimits: [String: Int] = [:] // Minutes
    private var schedules: [String: [DeviceActivitySchedule]] = [:]
    private var flutterResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_blocka", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "app_blocka/events", binaryMessenger: registrar.messenger())
        let instance = AppBlockaPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.app_blocka.backgroundMonitoring", using: nil) { task in
            instance.handleBackgroundMonitoring(task: task as! BGAppRefreshTask)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "initialize":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            scheduleBackgroundMonitoring()
            result(nil)
            
        case "startBackgroundService":
            scheduleBackgroundMonitoring()
            result(nil)
            
        case "stopBackgroundService":
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.example.app_blocka.backgroundMonitoring")
            result(nil)
            
        case "requestPermission":
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        print("Family Controls authorization granted")
                        result(true)
                    } catch {
                        print("Authorization failed: \(error)")
                        result(false)
                    }
                }
            } else {
                print("Family Controls not available on this iOS version")
                result(false)
            }
            
        case "checkPermission":
            if #available(iOS 16.0, *) {
                let status = AuthorizationCenter.shared.authorizationStatus
                print("Family Controls status: \(status)")
                result(status == .approved)
            } else {
                result(false)
            }
            
        case "getAvailableApps":
            if #available(iOS 16.0, *) {
                guard flutterResult == nil else {
                    print("getAvailableApps: Picker already in progress")
                    result(FlutterError(code: "PICKER_IN_PROGRESS", message: "Another picker is already active", details: nil))
                    return
                }
                print("getAvailableApps: Storing flutterResult")
                flutterResult = result
                getInstalledApps()
            } else {
                print("getAvailableApps: iOS version not supported")
                result([])
            }
            
        case "setTimeLimit":
            guard let args = call.arguments as? [String: Any],
                  let packageName = args["packageName"] as? String,
                  let limitMinutes = args["limitMinutes"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            timeLimits[packageName] = limitMinutes
            startMonitoringUsage(for: packageName)
            result(nil)
            
        case "setSchedule":
            guard let args = call.arguments as? [String: Any],
                  let packageName = args["packageName"] as? String,
                  let scheduleMaps = args["schedules"] as? [[String: Int]] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            var deviceSchedules: [DeviceActivitySchedule] = []
            for map in scheduleMaps {
                guard let startHour = map["startHour"],
                      let startMinute = map["startMinute"],
                      let endHour = map["endHour"],
                      let endMinute = map["endMinute"] else { continue }
                let start = DateComponents(hour: startHour, minute: startMinute)
                let end = DateComponents(hour: endHour, minute: endMinute)
                let schedule = DeviceActivitySchedule(
                    intervalStart: start,
                    intervalEnd: end,
                    repeats: true
                )
                deviceSchedules.append(schedule)
            }
            schedules[packageName] = deviceSchedules
            startDeviceActivityMonitoring(for: packageName)
            if restrictedApps.contains(packageName) {
                updateShield()
            }
            result(nil)
            
        case "blockApp":
            guard let args = call.arguments as? [String: String],
                  let bundleId = args["packageName"] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid package name", details: nil))
                return
            }
            restrictedApps.insert(bundleId)
            updateShield()
            result(nil)
            
        case "unblockApp":
            guard let args = call.arguments as? [String: String],
                  let bundleId = args["packageName"] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid package name", details: nil))
                return
            }
            restrictedApps.remove(bundleId)
            updateShield()
            result(nil)
            
        case "getUsageStats":
            let stats = getAppUsageStats()
            result(stats)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func presentFamilyActivityPicker(completion: @escaping ([[String: Any]]) -> Void) {
        if #available(iOS 16.0, *) {
            let status = AuthorizationCenter.shared.authorizationStatus
            print("presentFamilyActivityPicker: Authorization status: \(status)")
            guard status == .approved else {
                print("presentFamilyActivityPicker: Authorization not approved, requesting again")
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        print("Re-authorization granted")
                        self.presentFamilyActivityPicker(completion: completion)
                    } catch {
                        print("Re-authorization failed: \(error)")
                        completion([])
                    }
                }
                return
            }
            var selection = FamilyActivitySelection()
            print("presentFamilyActivityPicker: Initial selection: \(selection.applications.map { $0.bundleIdentifier ?? "nil" })")
            let pickerView = FamilyActivityPickerView(
                selection: $selection,
                onDone: { [weak self] in
                    guard let self = self else {
                        print("onDone: self is nil")
                        completion([])
                        return
                    }
                    print("onDone: Selection after dismissal: \(selection.applications.map { $0.bundleIdentifier ?? "nil" })")
                    self.selectedApps = selection.applications.reduce(into: [String: Application]()) { dict, app in
                        guard let bundleId = app.bundleIdentifier else {
                            print("Warning: Nil bundleIdentifier for app: \(app)")
                            return
                        }
                        print("Processing app: \(bundleId)")
                        dict[bundleId] = app
                    }
                    print("onDone: selectedApps updated: \(self.selectedApps.keys)")
                    let apps = self.selectedApps.map { (bundleId, app) in
                        let appInfo: [String: Any] = [
                            "packageName": bundleId,
                            "name": self.getAppName(for: bundleId) ?? bundleId,
                            "isSystemApp": bundleId.hasPrefix("com.apple.")
                        ]
                        return appInfo
                    }
                    print("onDone: Returning apps: \(apps)")
                    self.dismissPicker(completion: completion, apps: apps)
                },
                onCancel: { [weak self] in
                    guard let self = self else {
                        print("onCancel: self is nil")
                        completion([])
                        return
                    }
                    print("onCancel: Clearing selection")
                    self.selectedApps = [:]
                    self.dismissPicker(completion: completion, apps: [])
                }
            )
            if let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                print("Presenting picker on rootViewController")
                rootViewController.present(UIHostingController(rootView: pickerView), animated: true, completion: nil)
            } else {
                print("Error: No key window or rootViewController found to present picker")
                completion([])
            }
        } else {
            print("presentFamilyActivityPicker: iOS version not supported")
            completion([])
        }
    }
    
    private func dismissPicker(completion: @escaping ([[String: Any]]) -> Void, apps: [[String: Any]]) {
        if let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            print("Dismissing picker from rootViewController")
            rootViewController.dismiss(animated: true) {
                print("Picker dismissal completed")
                completion(apps)
            }
        } else {
            print("Warning: No key window or rootViewController found for dismissal")
            completion(apps)
        }
    }
    
    private func getInstalledApps() {
        if #available(iOS 16.0, *) {
            print("getInstalledApps: Starting picker presentation")
            presentFamilyActivityPicker { [weak self] apps in
                guard let self = self, let result = self.flutterResult else {
                    print("getInstalledApps: self or flutterResult is nil")
                    return
                }
                print("getInstalledApps: Returning apps to Flutter: \(apps)")
                result(apps)
                self.flutterResult = nil
            }
        } else {
            print("getInstalledApps: iOS version not supported")
            flutterResult?([])
            flutterResult = nil
        }
    }
    
    private func updateShield() {
        if #available(iOS 16.0, *) {
            let applications = restrictedApps.compactMap { bundleId -> ApplicationToken? in
                guard let app = selectedApps[bundleId] else { return nil }
                return app.token
            }
            store.shield.applications = restrictedApps.isEmpty ? nil : Set(applications)
        }
    }
    
    private func getAppName(for bundleId: String) -> String? {
        if bundleId == Bundle.main.bundleIdentifier {
            return Bundle.main.infoDictionary?["CFBundleName"] as? String
        }
        let appNameMapping: [String: String] = [
            "com.apple.mobilesafari": "Safari",
            "com.google.youtube": "YouTube",
            "com.apple.mobilnotes": "Notes"
        ]
        return appNameMapping[bundleId]
    }
    
    private func getAppIcon(for bundleId: String) -> String? {
        if bundleId == Bundle.main.bundleIdentifier,
           let iconName = Bundle.main.infoDictionary?["CFBundleIconName"] as? String,
           let icon = UIImage(named: iconName) {
            let size = CGSize(width: 48, height: 48)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            icon.draw(in: CGRect(origin: .zero, size: size))
            let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return scaledImage?.pngData()?.base64EncodedString()
        }
        return nil
    }
    
    private func startMonitoringUsage(for bundleId: String) {
        scheduleBackgroundMonitoring()
    }
    
    private func startDeviceActivityMonitoring(for bundleId: String) {
        guard let schedules = schedules[bundleId] else { return }
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName(rawValue: "restriction.\(bundleId)")
        do {
            for schedule in schedules {
                try center.startMonitoring(activityName, during: schedule)
            }
        } catch {
            print("Failed to start monitoring: \(error)")
        }
    }
    
    private func getAppUsageStats() -> [[String: Any]] {
        return restrictedApps.map { bundleId in
            var stat: [String: Any] = [
                "packageName": bundleId,
                "usageTime": 0
            ]
            if let iconData = getAppIcon(for: bundleId) {
                stat["icon"] = iconData
            }
            return stat
        }
    }
    
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleBackgroundMonitoring() {
        let request = BGAppRefreshTaskRequest(identifier: "com.example.app_blocka.backgroundMonitoring")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundMonitoring(task: BGAppRefreshTask) {
        scheduleBackgroundMonitoring()
        for (bundleId, limit) in timeLimits {
            let usage = 0 // Placeholder
            if usage / 60 >= limit {
                restrictedApps.insert(bundleId)
                updateShield()
                showNotification(title: "Time Limit Exceeded", body: "\(bundleId) has reached its time limit.")
            }
        }
        task.setTaskCompleted(success: true)
    }
}

extension AppBlockaPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping Flutter) -> FlutterError? {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            if let topApp = self.getTopAppBundleId(), self.restrictedApps.contains(topApp) {
                events(topApp)
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        return nil
    }

    private func getTopAppBundleId() -> String? {
        return nil // Simplified; implement actual top app detection
    }
}