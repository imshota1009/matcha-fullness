import DeviceActivity
import Foundation
import UserNotifications

/// Device Activity の拡張。見張っているアプリ(SNS など)の使用時間が決めた時間を超えたら、iOS から呼ばれる。
/// ここから直接アプリを開くことはできないので、「そろそろ一服しませんか」と通知する。
/// 通知をタップすると、アプリの Reminders が受け取り、点てる画面を直接開く。
final class ActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        let minutes = UserDefaults(suiteName: "group.com.imshota1009.spajam2026.shibui")?.object(forKey: "screenGuardMinutes") as? Int ?? 15
        let k = Int(event.rawValue.replacingOccurrences(of: "over", with: "")) ?? 1
        let content = UNMutableNotificationContent()
        content.title = "そろそろ一服しませんか"
        content.body = "SNS を \(minutes * k) 分見ました。抹茶を一杯点てて、目の前のことへ"
        content.sound = .default
        content.userInfo = ["open": "temae"]
        let request = UNNotificationRequest(identifier: "screen-guard-\(event.rawValue)", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}
