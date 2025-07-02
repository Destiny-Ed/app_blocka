import Flutter
import UIKit
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import BackgroundTasks

public class AppBlockaPlugin: NSObject, FlutterPlugin {
    private let store = ManagedSettingsStore()
    private var restrictedApps: Set<String> = []
    private var selectedApps: [String: Application] = [:]
    private var timeLimits: [String: Int] = [:]
    private var schedules: [String: [DeviceActivitySchedule]] = [:]
    private var flutterResult: FlutterResult?
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "app_blocka", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "app_blocka/events", binaryMessenger: registrar.messenger())
        let instance = AppBlockaPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.app_blocka.backgroundMonitoring", using: nil) { task in
            instance.handleBackgroundMonitoring(task: task as! BGAppRefreshTask)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        print("requestPermission: Authorization granted")
                        result(true)
                    } catch {
                        print("requestPermission: Authorization failed: \(error)")
                        result(false)
                    }
                }
            } else {
                print("requestPermission: iOS version not supported")
                result(false)
            }

        case "checkPermission":
            if #available(iOS 16.0, *) {
                let status = AuthorizationCenter.shared.authorizationStatus
                print("checkPermission: Status: \(status)")
                result(status == .approved)
            } else {
                result(false)
            }

        case "getAvailableApps":
            guard flutterResult == nil else {
                print("getAvailableApps: Picker already in progress")
                result(FlutterError(code: "PICKER_IN_PROGRESS", message: "Another picker is active", details: nil))
                return
            }
            flutterResult = result
            presentPicker()

        case "setTimeLimit":
            guard let args = call.arguments as? [String: Any],
                  let bundleId = args["packageName"] as? String,
                  let minutes = args["limitMinutes"] as? Int else {
                print("setTimeLimit: Invalid arguments")
                result(FlutterError(code: "INVALID_ARGS", message: "Missing params", details: nil))
                return
            }
            timeLimits[bundleId] = minutes
            startMonitoring(bundleId)
            result(nil)

        case "setSchedule":
            guard let args = call.arguments as? [String: Any],
                  let bundleId = args["packageName"] as? String,
                  let scheduleMaps = args["schedules"] as? [[String: Int]] else {
                print("setSchedule: Invalid arguments")
                result(FlutterError(code: "INVALID_ARGS", message: "Missing params", details: nil))
                return
            }
            var deviceSchedules: [DeviceActivitySchedule] = []
            for map in scheduleMaps {
                guard let sh = map["startHour"], let sm = map["startMinute"],
                      let eh = map["endHour"], let em = map["endMinute"] else { continue }
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: sh, minute: sm),
                    intervalEnd: DateComponents(hour: eh, minute: em),
                    repeats: true
                )
                deviceSchedules.append(schedule)
            }
            schedules[bundleId] = deviceSchedules
            startMonitoring(bundleId)
            result(nil)

        case "blockApp":
            guard let args = call.arguments as? [String: String], let bundleId = args["packageName"] else {
                print("blockApp: Invalid arguments")
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid package name", details: nil))
                return
            }
            print("blockApp: Attempting to block \(bundleId)")
            restrictedApps.insert(bundleId)
            applyShield()
            print("blockApp: restrictedApps: \(restrictedApps)")
            result(nil)

        case "unblockApp":
            guard let args = call.arguments as? [String: String], let bundleId = args["packageName"] else {
                print("unblockApp: Invalid arguments")
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid package name", details: nil))
                return
            }
            print("unblockApp: Attempting to unblock \(bundleId)")
            restrictedApps.remove(bundleId)
            applyShield()
            print("unblockApp: restrictedApps: \(restrictedApps)")
            result(nil)

        case "getUsageStats":
            let stats = restrictedApps.map { bundleId in
                [
                    "packageName": bundleId,
                    "usageTime": 0,
                    "icon": getAppIcon(bundleId) ?? ""
                ]
            }
            print("getUsageStats: Returning stats for \(stats.count) apps")
            result(stats)

        case "startBackgroundService":
            scheduleBackgroundTask()
            result(nil)

        case "stopBackgroundService":
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.example.app_blocka.backgroundMonitoring")
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentPicker() {
        guard #available(iOS 16.0, *) else {
            print("presentPicker: iOS version not supported")
            flutterResult?([])
            flutterResult = nil
            return
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("presentPicker: Authorization not approved")
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    print("presentPicker: Re-authorization granted")
                    self.presentPicker()
                } catch {
                    print("presentPicker: Re-authorization failed: \(error)")
                    flutterResult?([])
                    flutterResult = nil
                }
            }
            return
        }
        class SelectionHolder: ObservableObject {
            @Published var selection = FamilyActivitySelection()
        }
        let holder = SelectionHolder()
        print("presentPicker: Initial selection: \(holder.selection.applications.map { $0.bundleIdentifier ?? "nil" })")
        let pickerView = FamilyActivityPickerView(
            selection: Binding(
                get: { holder.selection },
                set: { holder.selection = $0 }
            ),
            onDone: { [weak self] in
                guard let self = self else {
                    print("onDone: self is nil")
                    self?.flutterResult?([])
                    self?.flutterResult = nil
                    return
                }
                let selection = holder.selection
                print("onDone: Raw selection: \(selection.applications.map { app in "bundle: \(app.bundleIdentifier ?? "nil"), token: \(String(describing: app.token))" })")
                self.selectedApps = selection.applications.reduce(into: [:]) { dict, app in
                    if let id = app.bundleIdentifier {
                        dict[id] = app
                    } else {
                        print("onDone: Skipping app with nil bundleIdentifier, token: \(String(describing: app.token))")
                    }
                }
                let apps = self.selectedApps.map { (id, app) -> [String: Any] in
                    [
                        "packageName": id,
                        "name": self.getAppName(id) ?? id,
                        "isSystemApp": id.hasPrefix("com.apple."),
                        "icon": self.getAppIcon(id) ?? ""
                    ]
                }
                print("onDone: Processed apps: \(apps)")
                self.dismissPicker(apps: apps)
            },
            onCancel: { [weak self] in
                print("onCancel: Picker cancelled")
                self?.selectedApps = [:]
                self?.dismissPicker(apps: [])
            }
        )
        let controller = UIHostingController(rootView: pickerView)
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first,
              let rootViewController = window.rootViewController else {
            print("presentPicker: No window scene or rootViewController found")
            flutterResult?([])
            flutterResult = nil
            return
        }
        print("presentPicker: Presenting picker")
        rootViewController.present(controller, animated: true) {
            print("presentPicker: Picker presented")
        }
    }

    private func dismissPicker(apps: [[String: Any]]) {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            print("dismissPicker: No window or rootViewController for dismissal")
            flutterResult?(apps)
            flutterResult = nil
            return
        }
        print("dismissPicker: Dismissing picker with apps: \(apps)")
        rootViewController.dismiss(animated: true) {
            print("dismissPicker: Picker dismissed, sending apps: \(apps)")
            self.flutterResult?(apps)
            self.flutterResult = nil
        }
    }

    private func applyShield() {
        guard #available(iOS 16.0, *) else {
            print("applyShield: iOS version not supported")
            return
        }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else {
            print("applyShield: Authorization not approved")
            return
        }
        let tokens = restrictedApps.compactMap { bundleId -> ApplicationToken? in
            guard let app = selectedApps[bundleId] else {
                print("applyShield: No Application for bundleId: \(bundleId)")
                return nil
            }
            guard let token = app.token else {
                print("applyShield: No ApplicationToken for bundleId: \(bundleId)")
                return nil
            }
            print("applyShield: Adding token for bundleId: \(bundleId)")
            return token
        }
        print("applyShield: Applying shield to \(tokens.count) tokens")
        store.shield.applications = tokens.isEmpty ? nil : Set(tokens)
        print("applyShield: Shield applied to \(store.shield.applications?.count ?? 0) apps")
    }

    private func scheduleBackgroundTask() {
        let task = BGAppRefreshTaskRequest(identifier: "com.example.app_blocka.backgroundMonitoring")
        task.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        do {
            try BGTaskScheduler.shared.submit(task)
            print("scheduleBackgroundTask: Task scheduled")
        } catch {
            print("scheduleBackgroundTask: Failed to schedule: \(error)")
        }
    }

    private func handleBackgroundMonitoring(task: BGAppRefreshTask) {
        scheduleBackgroundTask()
        for (bundleId, limit) in timeLimits {
            let usage = 0 // TODO: Implement actual usage tracking
            if usage / 60 >= limit {
                restrictedApps.insert(bundleId)
                applyShield()
                showNotification(title: "Time Limit Exceeded", body: "\(getAppName(bundleId) ?? bundleId) exceeded usage")
                eventSink?(bundleId)
            }
        }
        task.setTaskCompleted(success: true)
    }

    private func startMonitoring(_ bundleId: String) {
        guard let scheduleList = schedules[bundleId] else {
            print("startMonitoring: No schedules for \(bundleId)")
            return
        }
        let center = DeviceActivityCenter()
        for schedule in scheduleList {
            do {
                try center.startMonitoring(DeviceActivityName(rawValue: "monitor.\(bundleId)"), during: schedule)
                print("startMonitoring: Started for \(bundleId)")
            } catch {
                print("startMonitoring: Failed for \(bundleId): \(error)")
            }
        }
    }

    private func getAppName(_ id: String) -> String? {
        if id == Bundle.main.bundleIdentifier {
            return Bundle.main.infoDictionary?["CFBundleName"] as? String
        }
        return [
            "com.apple.mobilesafari": "Safari",
            "com.google.youtube": "YouTube",
            "com.apple.mobilnotes": "Notes"
        ][id] ?? id
    }

    private func getAppIcon(_ id: String) -> String? {
        if id == Bundle.main.bundleIdentifier,
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

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("showNotification: Failed to deliver: \(error)")
            } else {
                print("showNotification: Delivered: \(title) - \(body)")
            }
        }
    }
}

extension AppBlockaPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}