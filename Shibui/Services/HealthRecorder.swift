import Foundation
import HealthKit

/// 点てた時間を、ヘルスケアの「マインドフルネス」(mindfulSession)として書き込む(5章 L-5)。読み取りはしない。
/// 許可は、初めて点て終えたときに一度だけ求める。断られても、アプリの動きは変えない。設定でオフにできる。
enum HealthRecorder {
    static let enabledKey = "healthOn"
    private static let store = HKHealthStore()

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    static func record(from start: Date, to end: Date) {
        guard isEnabled, HKHealthStore.isHealthDataAvailable(), end > start,
              let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        Task {
            // 初めてのときだけ許可の画面が出る(2回目以降は、すぐ戻る)
            _ = try? await store.requestAuthorization(toShare: [type], read: [])
            guard store.authorizationStatus(for: type) == .sharingAuthorized else { return }
            let sample = HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
            try? await store.save(sample)
        }
    }
}
