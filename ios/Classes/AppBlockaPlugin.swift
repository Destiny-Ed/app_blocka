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
                        result(true)
                    } catch {
                        result(false)
                    }
                }
            } else {
                result(false)
            }

        case "checkPermission":
            if #available(iOS 16.0, *) {
                result(AuthorizationCenter.shared.authorizationStatus == .approved)
            } else {
                result(false)
            }

        case "getAvailableApps":
            flutterResult = result
            presentPicker()

        case "setTimeLimit":
            guard let args = call.arguments as? [String: Any],
                  let bundleId = args["packageName"] as? String,
                  let minutes = args["limitMinutes"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing params", details: nil))
                return
            }
            timeLimits[bundleId] = minutes
            result(nil)

        case "setSchedule":
            guard let args = call.arguments as? [String: Any],
                  let bundleId = args["packageName"] as? String,
                  let scheduleMaps = args["schedules"] as? [[String: Int]] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing params", details: nil))
                return
            }

            var deviceSchedules: [DeviceActivitySchedule] = []
            for map in scheduleMaps {
                guard let sh = map["startHour"], let sm = map["startMinute"],
                      let eh = map["endHour"], let em = map["endMinute"] else { continue }
                let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: sh, minute: sm), intervalEnd: DateComponents(hour: eh, minute: em), repeats: true)
                deviceSchedules.append(schedule)
            }

            schedules[bundleId] = deviceSchedules
            startMonitoring(bundleId)
            result(nil)

        case "blockApp":
            guard let args = call.arguments as? [String: String], let bundleId = args["packageName"] else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            restrictedApps.insert(bundleId)
            applyShield()
            result(nil)

        case "unblockApp":
            guard let args = call.arguments as? [String: String], let bundleId = args["packageName"] else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            restrictedApps.remove(bundleId)
            applyShield()
            result(nil)

        case "getUsageStats":
            let stats = restrictedApps.map {
                [
                    "packageName": $0,
                    "usageTime": 0,
                    "icon": getAppIcon($0)
                ]
            }
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
            flutterResult?([])
            return
        }

        let holder = SelectionHolder()
        let pickerView = FamilyActivityPickerView(selection: $holder.selection, onDone: {
            self.selectedApps = holder.selection.applications.reduce(into: [:]) { dict, app in
                if let id = app.bundleIdentifier { dict[id] = app }
            }

            let apps = self.selectedApps.map { (id, app) -> [String: Any] in
                [
                    "packageName": id,
                    "name": self.getAppName(id),
                    "isSystemApp": id.hasPrefix("com.apple."),
                    "icon": self.getAppIcon(id)
                ]
            }

            self.flutterResult?(apps)
            self.flutterResult = nil
        }, onCancel: {
            self.flutterResult?([])
            self.flutterResult = nil
        })

        let controller = UIHostingController(rootView: pickerView)
        if let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first {
            window.rootViewController?.present(controller, animated: true)
        }
    }

    private func applyShield() {
        guard #available(iOS 16.0, *) else { return }
        let tokens = restrictedApps.compactMap { selectedApps[$0]?.token }
        store.shield.applications = Set(tokens)
    }

    private func scheduleBackgroundTask() {
        let task = BGAppRefreshTaskRequest(identifier: "com.example.app_blocka.backgroundMonitoring")
        task.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(task)
    }

    private func handleBackgroundMonitoring(task: BGAppRefreshTask) {
        scheduleBackgroundTask()
        for (bundleId, limit) in timeLimits {
            let usage = 0 // TODO: actual usage
            if usage / 60 >= limit {
                restrictedApps.insert(bundleId)
                applyShield()
                showNotification(title: "Time Limit", body: "\(bundleId) exceeded usage")
                eventSink?(bundleId)
            }
        }
        task.setTaskCompleted(success: true)
    }

    private func startMonitoring(_ bundleId: String) {
        guard let scheduleList = schedules[bundleId] else { return }
        let center = DeviceActivityCenter()
        for schedule in scheduleList {
            try? center.startMonitoring(DeviceActivityName(rawValue: "monitor.\(bundleId)"), during: schedule)
        }
    }

    private func getAppName(_ id: String) -> String {
        return [
            "com.apple.mobilesafari": "Safari",
            "com.google.youtube": "YouTube"
        ][id] ?? id
    }

    private func getAppIcon(_ id: String) -> String? {
        return nil // Optional: Implement icon encoding as base64 PNG
    }
}

@available(iOS 16.0, *)
class SelectionHolder: ObservableObject {
    @Published var selection = FamilyActivitySelection()
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
