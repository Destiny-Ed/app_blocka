import DeviceActivity
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let bundleId = activity.rawValue.split(separator: ".").last else { return }

        // Retrieve application token from shared UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.example.app_blocka")
        if let tokenData = defaults?.data(forKey: "token_\(bundleId)") {
            do {
                if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: ApplicationToken.self, from: tokenData) {
                    store.shield.applications = [token]
                    showLocalNotification(title: "App Restriction Started", desc: "\(bundleId) is now restricted.")
                }
            } catch {
                print("Failed to unarchive token for \(bundleId): \(error)")
            }
        }
    }

    override func intervalDidEnd(for: activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        showLocalNotification(title: "App Restriction Stopped", desc: "Restrictions have been lifted.")
    }

    private func showLocalNotification(title: String, desc: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = desc
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}