import Foundation
import Observation
import UIKit
import UserNotifications

/// 入口の通知(SPEC 5章 G)。設定で決めた時刻(複数)に毎日ローカル通知を出す。タップすると点てる(本体)を開く。
@MainActor
@Observable
final class Reminders: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Reminders()
    private static let key = "reminderTimes"
    private static let prefix = "matcha-reminder-"

    /// 通知をタップして開いたとき true(点てる画面を開く合図)
    var openTemae = false

    /// 通知時刻(その日の 0:00 からの分)
    private(set) var times: [Int] = (UserDefaults.standard.array(forKey: key) as? [Int]) ?? []

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func add(_ minutes: Int) {
        guard !times.contains(minutes) else { return }
        times = (times + [minutes]).sorted()
        save()
    }

    func remove(_ minutes: Int) {
        times.removeAll { $0 == minutes }
        save()
    }

    func change(_ old: Int, to new: Int) {
        times = (times.filter { $0 != old && $0 != new } + [new]).sorted()
        save()
    }

    private func save() {
        UserDefaults.standard.set(times, forKey: Self.key)
        Task { await reschedule() }
    }

    /// 決めた時刻で、毎日くり返す通知を出し直す
    func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard !times.isEmpty else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        for m in times {
            let content = UNMutableNotificationContent()
            content.title = "一杯の時間です"
            content.body = "スマホを置いて、抹茶を点てましょう。作業の前の儀式に"
            content.sound = .default
            content.userInfo = ["open": "temae"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: m / 60, minute: m % 60), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: Self.prefix + "\(m)", content: content, trigger: trigger))
        }
    }

    // アプリを開いている間も、通知を表示する
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { completionHandler([.banner, .sound]) }
    }

    // 通知をタップしたら、点てる画面を開く。
    // 完了の合図は必ずメインスレッドで返す(別のスレッドで返すと、UIKit が止まる)
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let open = response.notification.request.content.userInfo["open"] as? String == "temae"
        DispatchQueue.main.async {
            if open { MainActor.assumeIsolated { self.openTemae = true } }
            completionHandler()
        }
    }

    static func label(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
}
