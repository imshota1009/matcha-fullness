import DeviceActivity
import FamilyControls
import Foundation
import Observation

/// SNS を見すぎたら茶室へ(SPEC 5章「余力があれば」6)。Screen Time API(Family Controls + Device Activity)を使う。
/// - 設定で、見張るアプリ(SNS など)と「何分使ったら」を選ぶ
/// - その時間を超えたら、Device Activity の拡張(ShibuiActivityMonitor)が「そろそろ一服しませんか」と通知する。
///   通知をタップすると、点てる画面が直接開く(Reminders と同じ仕組み)
/// - 同じ時間ぶん使うたびに、また知らせる(1日に最大 8 回)
/// 注意: Family Controls は Apple の特別な許可(entitlement)が必要。開発版(Xcode から入れたデモ機)でだけ動く。
/// TestFlight 版には許可を入れていないので、設定に「この版では使えません」と出る。
@MainActor
@Observable
final class ScreenGuard {
    static let shared = ScreenGuard()
    /// アプリと拡張で共有する保存場所(App Group)
    static let suite = UserDefaults(suiteName: "group.com.imshota1009.spajam2026.shibui")
    static let selectionKey = "screenGuardSelection"
    static let minutesKey = "screenGuardMinutes"
    static let activity = DeviceActivityName("matcha.sns")

    var selection = FamilyActivitySelection()
    var minutes: Int = 15
    var isOn = false
    /// 最後に起きたエラー(画面に短く出す)
    var message: String?

    private init() {
        if let data = Self.suite?.data(forKey: Self.selectionKey),
           let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) { selection = s }
        minutes = Self.suite?.object(forKey: Self.minutesKey) as? Int ?? 15
        isOn = !DeviceActivityCenter().activities.isEmpty
    }

    var selectedCount: Int { selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count }

    /// 使用状況を見る許可を求める(初めてのときだけ画面が出る)
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            message = "この版では使えません(Screen Time の許可がありません)。デモ機の開発版でお試しください"
            return false
        }
    }

    /// 見張りを始める。選んだアプリの使用時間が minutes の倍数に届くたびに、拡張が呼ばれる
    func start() async {
        guard await requestAuthorization() else { isOn = false; return }
        guard selectedCount > 0 else { message = "見張るアプリを選んでください"; isOn = false; return }
        save()
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59), repeats: true)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for k in 1...8 {
            events[DeviceActivityEvent.Name("over\(k)")] = DeviceActivityEvent(
                applications: selection.applicationTokens, categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens, threshold: DateComponents(minute: minutes * k))
        }
        do {
            let center = DeviceActivityCenter()
            center.stopMonitoring([Self.activity])
            try center.startMonitoring(Self.activity, during: schedule, events: events)
            isOn = true
            message = nil
        } catch {
            isOn = false
            message = "見張りを始められませんでした: \(error.localizedDescription)"
        }
    }

    func stop() {
        DeviceActivityCenter().stopMonitoring([Self.activity])
        isOn = false
    }

    func save() {
        if let data = try? JSONEncoder().encode(selection) { Self.suite?.set(data, forKey: Self.selectionKey) }
        Self.suite?.set(minutes, forKey: Self.minutesKey)
    }
}
