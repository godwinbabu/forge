import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleBlockEndingSoon(endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Focus session ends in 5 minutes"
        content.body = "Your block is almost over."
        content.sound = .default

        let triggerDate = endDate.addingTimeInterval(-300) // 5 min before end
        guard triggerDate > Date() else { return }
        let interval = triggerDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "block-ending-soon", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendBlockStarted(profileName: String, endDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "\(profileName) activated"
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        content.body = "Ends at \(formatter.string(from: endDate))"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "block-started", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendBlockEnded(blockedAttempts: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your block has ended!"
        content.body = "You blocked \(blockedAttempts) distraction\(blockedAttempts == 1 ? "" : "s")."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "block-ended", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "block-ending-soon"
        ])
    }
}
