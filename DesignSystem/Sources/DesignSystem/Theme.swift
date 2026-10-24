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
        // 渋分の4色: 抹茶・黒に近い茶(焦茶)・白・灰。ほかの色は使わない
        /// 抹茶
        public static let matcha = Color(red: 0.36, green: 0.47, blue: 0.22)
        /// 焦茶(黒に近い茶)
        public static let kogecha = Color(red: 0.17, green: 0.12, blue: 0.09)
        /// 白(生成り寄り)
        public static let shiro = Color(red: 0.98, green: 0.975, blue: 0.96)
        /// 灰
        public static let hai = Color(red: 0.47, green: 0.45, blue: 0.43)

        /// 画面の背景
        public static var background: Color { Theme.base == .light ? shiro : kogecha }
        /// 一段上の面(シート・入力欄など)。影ではなく色の差で階層を作る
        public static var surface: Color { Theme.base == .light ? Color(red: 0.93, green: 0.925, blue: 0.91) : Color(red: 0.24, green: 0.19, blue: 0.15) }
        /// 本文
        public static var text: Color { Theme.base == .light ? kogecha : shiro }
        /// 補足の文字(背景とのコントラスト 4.5:1 以上)
        public static var secondaryText: Color { Theme.base == .light ? hai : Color(red: 0.72, green: 0.70, blue: 0.67) }
        /// 区切り線
        public static var separator: Color { Theme.base == .light ? Color(red: 0.86, green: 0.85, blue: 0.83) : Color(red: 0.32, green: 0.27, blue: 0.23) }
        /// アクセント(主要操作)= 抹茶
        public static var accent: Color { matcha }
        /// アクセントの上に載る文字
        public static var onAccent: Color { shiro }
        /// 正常・進行中(抹茶で表す)
        public static var positive: Color { matcha }
        /// 注意・警告も4色の範囲で表す(色だけに頼らず、アイコンと文字で伝える)
        public static var caution: Color { text }
        public static var vermilion: Color { text }
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
