import UIKit

/// 節目の触覚フィードバック。画面側はここだけを呼ぶ。
@MainActor
public enum Haptics {
    /// 設定の「振動」のキー(UserDefaults)。オフのときは何も鳴らさない
    public static let storageKey = "hapticsOn"
    private static var isOn: Bool { UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true }

    /// 決定・完了
    public static func success() { if isOn { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    /// 選択の切り替え
    public static func selection() { if isOn { UISelectionFeedbackGenerator().selectionChanged() } }
    /// 警告・失敗
    public static func warning() { if isOn { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    /// 判子を押すような、重めの一回
    public static func impact() { if isOn { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() } }
}
