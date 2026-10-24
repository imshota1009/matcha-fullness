import Foundation
import Observation
import WidgetKit

/// 記録を画面から扱う。変更のたびに保存し、ウィジェットを更新する。記録は消さずに残す(習慣づくり)。
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

    /// 一服の結果。画面に出すために返す
    struct Result {
        let score: Int
        let points: Int
        let isBest: Bool
        let rankBefore: Rank
        let rankAfter: Rank
    }

    /// 点前の点数を記録して茶点を足す(点数ぶん + 自己ベスト更新で 50)。一事はあとで `setIchiji` で入れる
    func serve(score: Int, praise: String, mode: WhiskMode) -> Result {
        let before = record.totalPoints
        let isBest = !record.servings.isEmpty && score > record.bestScore
        let points = score + (isBest ? 50 : 0)
        if record.matchaCups > 0 { record.matchaCups -= 1 }
        record.servings.append(Serving(date: .now, praise: praise, ichiji: "", score: score, points: points, mode: mode))
        persist()
        return Result(score: score, points: points, isBest: isBest,
                      rankBefore: Rank.current(for: before), rankAfter: Rank.current(for: record.totalPoints))
    }

    func setIchiji(_ text: String) {
        guard !record.servings.isEmpty else { return }
        record.servings[record.servings.count - 1].ichiji = text
        persist()
    }

    /// 石臼が回った分を足す。1杯ぶん挽けたら true
    @discardableResult
    func grind(seconds: Double) -> Bool {
        record.groundSeconds += seconds
        record.focusByDay[TeaRecord.dayKey(), default: 0] += seconds
        record.grindProgress += seconds / focusSeconds
        var finished = false
        if record.grindProgress >= 1 {
            record.grindProgress = 0
            record.matchaCups += 1
            record.focusSessions += 1
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
