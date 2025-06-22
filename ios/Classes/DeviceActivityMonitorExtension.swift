import DeviceActivity
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let bundleId = activity.rawValue.split(separator: ".").last else { return }
        store.shield.applications = [Application(bundleIdentifier: String(bundleId))]
        showLocalNotification(title: "App Restriction Started", desc: "\(bundleId) is now restricted.")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        showLocalNotification(title: "App Restriction Stopped", desc: "Restrictions have been lifted.")
    }

    func showLocalNotification(title: String, desc: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = desc
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}