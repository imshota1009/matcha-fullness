import Foundation
import Observation
import WidgetKit

/// 画面から使う記録の置き場。変更のたびに保存し、ウィジェットを更新する。
@Observable
final class EntryStore {
    private(set) var entries: [Record]
    /// 直前に消した記録(「元に戻す」用。寛容性)
    private(set) var lastDeleted: (entry: Record, index: Int)?

    init() {
        let saved = SharedStore.load()
        entries = saved.isEmpty ? MockData.entries : saved
    }

    func add(_ entry: Record) {
        entries.insert(entry, at: 0)
        persist()
    }

    func delete(_ entry: Record) {
        guard let index = entries.firstIndex(of: entry) else { return }
        entries.remove(at: index)
        lastDeleted = (entry, index)
        persist()
    }

    func undoDelete() {
        guard let lastDeleted else { return }
        entries.insert(lastDeleted.entry, at: min(lastDeleted.index, entries.count))
        self.lastDeleted = nil
        persist()
    }

    private func persist() {
        SharedStore.save(entries)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
