import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private let reminderIdentifier = "aurora.daily-briefing-reminder"
    private let enabledKey = "reminderEnabled"
    private let hourKey = "reminderHour"
    private let minuteKey = "reminderMinute"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }
    @Published var time: Date {
        didSet {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            UserDefaults.standard.set(comps.hour, forKey: hourKey)
            UserDefaults.standard.set(comps.minute, forKey: minuteKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: enabledKey)
        let hour = defaults.object(forKey: hourKey) as? Int ?? 7
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        time = Calendar.current.date(from: comps) ?? Date()
    }

    func setEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await requestAuthorization()
            guard granted else {
                isEnabled = false
                return
            }
            isEnabled = true
            scheduleNotification()
        } else {
            isEnabled = false
            cancelNotification()
        }
    }

    func updateTime(_ newTime: Date) {
        time = newTime
        if isEnabled { scheduleNotification() }
    }

    private func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Aurora Daily Briefing"
        content.body = "Ready to talk through today? Open Aurora to start your briefing."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
}
