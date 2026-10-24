import Foundation
import UserNotifications

/// 柿が熟した時刻に知らせるローカル通知。
enum Notifier {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleRipe(_ kaki: Kaki) {
        let seconds = kaki.ripeAt.timeIntervalSinceNow
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "「\(kaki.name)」が食べごろです"
        content.body = "干して、待った。それでも、まだ欲しいですか?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: kaki.id.uuidString, content: content, trigger: trigger))
    }

    static func cancel(_ kaki: Kaki) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [kaki.id.uuidString])
    }
}
