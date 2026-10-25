import Foundation
import UserNotifications

enum Notifier {
    static func ask() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    static func cancel(_ h: Homework) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [h.id.uuidString + "a", h.id.uuidString + "b"])
    }
    /// Два напоминания: за сутки и за час до срока.
    static func schedule(_ h: Homework) {
        cancel(h)
        guard !h.done else { return }
        let center = UNUserNotificationCenter.current()
        let plan: [(String, TimeInterval, String)] = [("a", -86400, "Срок завтра"), ("b", -3600, "Срок через час")]
        for (suffix, offset, label) in plan {
            let date = h.due.addingTimeInterval(offset)
            guard date > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(label): \(h.subject)"
            content.body = h.title
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: h.id.uuidString + suffix, content: content, trigger: trigger))
        }
    }
}
