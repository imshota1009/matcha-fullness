import UIKit

/// 節目の触覚フィードバック。画面側はここだけを呼ぶ。
@MainActor
public enum Haptics {
    /// 決定・完了
    public static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// 選択の切り替え
    public static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// 警告・失敗
    public static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    /// 判子を押すような、重めの一回
    public static func impact() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}
