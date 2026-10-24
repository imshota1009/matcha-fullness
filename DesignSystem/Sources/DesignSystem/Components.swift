import SwiftUI

// MARK: - 画面の骨格

/// 全画面共通の骨格。内容を上に、主要操作を親指の届く下部に固定する。
/// 主要操作は1画面に1つまで。不要なら `bottom` を省略する。
public struct DSScreen<Content: View, Bottom: View>: View {
    private let title: String
    private let content: Content
    private let bottom: Bottom

    public init(_ title: String, @ViewBuilder content: () -> Content, @ViewBuilder bottom: () -> Bottom) {
        self.title = title
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        // 下に置くものがないときは、下の余白(safeAreaInset)を付けない。
        // 付けると、シートの中で中身より下の白い余白までスクロールできてしまう
        if Bottom.self == EmptyView.self {
            scroll
        } else {
            scroll.safeAreaInset(edge: .bottom) {
                bottom
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
    }

    private var scroll: some View {
        ScrollView {
            // 中身を1つの VStack にまとめる
            VStack(alignment: .leading) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.l)
        }
        // 中身が画面に収まるときは、引っぱってもスクロールしない
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.Palette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

public extension DSScreen where Bottom == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(title, content: content, bottom: { EmptyView() })
    }
}

// MARK: - 主要操作ボタン

/// 画面下部に置く主要操作ボタン。押すと縮み、触覚が返る(アフォーダンスとモディファイア)。
public struct PrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
            .foregroundStyle(Theme.Palette.onAccent)
            .background(Theme.Palette.accent, in: .rect(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// 押している間だけ少し縮む。影やグローは使わない。
public struct PressScaleStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

// MARK: - 見出し

/// 小さめの見出しと細い区切り線で、カードを使わずに階層を作る。
public struct SectionHeader: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.dsSection)
                .foregroundStyle(Theme.Palette.secondaryText)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Theme.Palette.separator)
                .frame(height: 1)
        }
        .padding(.top, Theme.Spacing.l)
    }
}

// MARK: - 閉じるボタン

/// シート右上の閉じるボタン。どの状態からでも抜けられるようにする(脱出性)。
public struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss
    public init() {}

    public var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                .contentShape(.rect)
        }
        .accessibilityLabel("閉じる")
    }
}

// MARK: - 状態ラベル

/// 状態をアイコン・文字・色の3つで伝える。色だけに頼らない。
public struct StatusLabel: View {
    public enum Kind { case positive, caution, alert, neutral }

    private let text: String
    private let kind: Kind
    public init(_ text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        Label(text, systemImage: symbol)
            .font(.dsCaption.weight(.medium))
            .foregroundStyle(color)
    }

    private var symbol: String {
        switch kind {
        case .positive: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .alert: "exclamationmark.octagon.fill"
        case .neutral: "circle"
        }
    }

    private var color: Color {
        switch kind {
        case .positive: Theme.Palette.positive
        case .caution: Theme.Palette.text
        case .alert: Theme.Palette.vermilion
        case .neutral: Theme.Palette.secondaryText
        }
    }
}

// MARK: - 空の状態

/// 何もないときの案内と、最初の1歩のボタン。デモで空の画面を見せないためにも使う。
public struct EmptyState: View {
    private let title: String
    private let message: String
    private let systemImage: String

    public init(_ title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Theme.Palette.secondaryText)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.text)
            Text(message)
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 判子

/// 朱色の判子。絵文字を使わず図形で描く。`isStamped` が true になると、押し込む動きと触覚で現れる。
public struct Stamp: View {
    private let text: String
    private let isStamped: Bool
    private let size: CGFloat

    public init(_ text: String, isStamped: Bool, size: CGFloat = 88) {
        self.text = text
        self.isStamped = isStamped
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12)
                .strokeBorder(Theme.Palette.vermilion, lineWidth: size * 0.06)
            Text(text)
                .font(.system(size: size * 0.32, weight: .heavy, design: .serif))
                .foregroundStyle(Theme.Palette.vermilion)
                .minimumScaleFactor(0.5)
                .padding(size * 0.1)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-6))
        .scaleEffect(isStamped ? 1 : 1.6)
        .opacity(isStamped ? 1 : 0)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: isStamped)
        .onChange(of: isStamped) { _, stamped in
            if stamped { Haptics.impact() }
        }
        .accessibilityLabel("判子 \(text)")
    }
}
