import Foundation
import Observation
import WidgetKit

/// 軒下の柿をまとめて扱う。変更のたびに保存し、ウィジェットと通知を更新する。
@Observable
final class KakiStore {
    private(set) var kakis: [Kaki]
    /// 直前に降ろした柿(「元に戻す」用。寛容性)
    private(set) var lastRemoved: Kaki?

    init() {
        kakis = SharedStore.load() ?? MockData.kakis
    }

    /// 干している最中のもの。食べごろが近い順
    var hanging: [Kaki] {
        kakis.filter { $0.decision == nil }
            .sorted { $0.ripeAt < $1.ripeAt }
    }

    /// 決めた柿。新しい順
    var decided: [Kaki] {
        kakis.filter { $0.decision != nil }
            .sorted { ($0.decidedAt ?? .distantPast) > ($1.decidedAt ?? .distantPast) }
    }

    var savedAmount: Int { SharedStore.savedAmount(kakis) }

    func hang(name: String, price: Int, dryingSeconds: TimeInterval, kind: Kaki.Kind) {
        let kaki = Kaki(name: name, price: price, hungAt: .now, dryingSeconds: dryingSeconds, kind: kind)
        kakis.append(kaki)
        Notifier.scheduleRipe(kaki)
        persist()
    }

    func decide(_ kaki: Kaki, _ decision: Kaki.Decision) {
        guard let i = kakis.firstIndex(where: { $0.id == kaki.id }) else { return }
        kakis[i].decision = decision
        kakis[i].decidedAt = .now
        Notifier.cancel(kaki)
        persist()
    }

    /// 熟す前に降ろす(削除)。ホームで元に戻せる
    func remove(_ kaki: Kaki) {
        kakis.removeAll { $0.id == kaki.id }
        lastRemoved = kaki
        Notifier.cancel(kaki)
        persist()
    }

    func undoRemove() {
        guard let lastRemoved else { return }
        kakis.append(lastRemoved)
        if !lastRemoved.isRipe() { Notifier.scheduleRipe(lastRemoved) }
        self.lastRemoved = nil
        persist()
    }

    private func persist() {
        SharedStore.save(kakis)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
