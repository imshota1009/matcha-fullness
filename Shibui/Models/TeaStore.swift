import Foundation
import Observation
import WidgetKit

/// 記録を画面から扱う。変更のたびに保存し、ウィジェットを更新する。
@Observable
final class TeaStore {
    private(set) var record: TeaRecord

    /// デモ用の早送り(F8)。集中25分を10秒にする
    var isFastMode: Bool {
        didSet { UserDefaults.standard.set(isFastMode, forKey: "fastMode") }
    }

    init() {
        record = SharedStore.load() ?? MockData.record
        isFastMode = UserDefaults.standard.object(forKey: "fastMode") as? Bool ?? true
    }

    /// 集中1回の長さ(秒)
    var focusSeconds: Double { isFastMode ? 10 : 25 * 60 }

    /// 一服を記録する。挽いた抹茶があれば1杯使う(なければ最初の一服としてもてなす)
    func serve(praise: String, ichiji: String) {
        if record.matchaCups > 0 { record.matchaCups -= 1 }
        record.servings.append(Serving(date: .now, praise: praise, ichiji: ichiji))
        persist()
    }

    /// 石臼が回った分を足す。1杯ぶん挽けたら true
    @discardableResult
    func grind(seconds: Double) -> Bool {
        record.groundSeconds += seconds
        record.grindProgress += seconds / focusSeconds
        var finished = false
        if record.grindProgress >= 1 {
            record.grindProgress = 0
            record.matchaCups += 1
            finished = true
        }
        persist(reloadWidget: finished)
        return finished
    }

    private func persist(reloadWidget: Bool = true) {
        SharedStore.save(record)
        if reloadWidget { WidgetCenter.shared.reloadAllTimelines() }
    }
}
