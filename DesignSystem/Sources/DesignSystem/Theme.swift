import SwiftUI

/// 色・余白・角丸・文字の値をまとめた場所。画面側では数値を直書きせず、ここを参照する。
/// ベースの明暗(ライト / ダーク)は CLAUDE.md の【当日記入】。決まったら `Theme.base` を書き換えるだけで全画面が切り替わる。
public enum Theme {
    public enum Base { case light, dark }

    /// 当日決める。アプリの入口で `.preferredColorScheme(Theme.colorScheme)` を付けて固定する。
    nonisolated(unsafe) public static var base: Base = .light

    public static var colorScheme: ColorScheme { base == .light ? .light : .dark }

    // MARK: - 色(白・黒・グレー + アクセント1色 + 警告の朱色)

    public enum Palette {
        /// 画面の背景
        public static var background: Color { Theme.base == .light ? Color(white: 0.99) : Color(white: 0.06) }
        /// 一段上の面(シート・入力欄など)。影ではなく色の差で階層を作る
        public static var surface: Color { Theme.base == .light ? Color(white: 0.955) : Color(white: 0.13) }
        /// 本文
        public static var text: Color { Theme.base == .light ? Color(white: 0.08) : Color(white: 0.96) }
        /// 補足の文字(背景とのコントラスト 4.5:1 以上を保つ濃さ)
        public static var secondaryText: Color { Theme.base == .light ? Color(white: 0.40) : Color(white: 0.66) }
        /// 区切り線
        public static var separator: Color { Theme.base == .light ? Color(white: 0.88) : Color(white: 0.22) }
        /// アクセント(主要操作に使う)。案が決まったら1色だけ差し替える
        public static var accent: Color { Theme.base == .light ? Color(white: 0.08) : Color(white: 0.96) }
        /// アクセントの上に載る文字
        public static var onAccent: Color { Theme.base == .light ? .white : .black }
        /// 警告・期限・破壊的操作。純粋な赤ではなく朱色(色覚の多様性に配慮)
        public static let vermilion = Color(red: 0.89, green: 0.31, blue: 0.18)
        /// 正常・進行中(JIS C0448 の緑)
        public static let positive = Color(red: 0.16, green: 0.55, blue: 0.33)
        /// 注意(JIS C0448 の黄。文字には使わず、アイコンと併用する)
        public static let caution = Color(red: 0.86, green: 0.62, blue: 0.10)
    }

    // MARK: - 余白(4 の倍数)

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
        /// 画面の左右の余白。広げすぎない
        public static let screen: CGFloat = 16
    }

    // MARK: - 角丸

    public enum Radius {
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
    }

    // MARK: - サイズ

    public enum Size {
        /// HIG のタッチターゲット下限
        public static let minTouch: CGFloat = 44
        /// 画面下部の主要操作ボタンの高さ
        public static let primaryButton: CGFloat = 54
    }
}

public extension Font {
    /// 見出しは控えめに。巨大な見出しは使わない
    static let dsTitle = Font.title2.weight(.semibold)
    static let dsSection = Font.footnote.weight(.semibold)
    static let dsBody = Font.body
    static let dsCaption = Font.footnote
    /// 「今の状態」を見せる大きな数字(1画面に1つまで)
    static let dsHero = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
}
