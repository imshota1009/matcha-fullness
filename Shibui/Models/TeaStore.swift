import Foundation
import Observation

/// 記録を画面から扱う。変更のたびに端末へ保存する。
@Observable
final class TeaStore {
    private(set) var record: TeaRecord

    init() {
        record = SharedStore.load() ?? MockData.record
    }

    /// 点てた一杯を記録する
    func serve(score: Int, praise: String) {
        record.servings.append(Serving(date: .now, praise: praise, ichiji: "", score: score, points: 0, mode: .finger))
        persist()
    }

    /// 一杯の記録を消す(記録の画面から)
    func deleteServing(_ id: UUID) {
        record.servings.removeAll { $0.id == id }
        persist()
    }

    /// 記録をすべて消して、はじめからにする
    func deleteAll() {
        record = TeaRecord()
        persist()
    }

    private func persist() {
        SharedStore.save(record)
    }
}
