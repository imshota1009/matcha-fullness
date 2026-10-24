import DesignSystem
import SwiftUI

/// はじめの説明(3ページ)。Mobbin の Crouton(ようこそ)・Klarna(価値を3行)・Things 3(短く、すぐ使える)を参考にした。
/// - 主要操作は下部の1ボタンだけ。左右スワイプでもページを移れる
/// - どのページからでも「スキップ」で抜けられる(脱出性)
/// - 文言は `OnboardingContent` の1か所で差し替える
struct OnboardingView: View {
    let onFinish: () -> Void
    /// 起動引数 `-onboardingPage N` で最初のページを指定できる(画面確認用)
    @State private var page = UserDefaults.standard.integer(forKey: "onboardingPage")
    @State private var stamped = false

    private let pageCount = 4
    @AppStorage(WhiskMode.storageKey) private var mode = WhiskMode.gyro
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("スキップ") { finish() }
                        .font(.dsCaption.weight(.medium))
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .frame(minWidth: Theme.Size.minTouch, minHeight: Theme.Size.minTouch)
                }
            }
            .frame(height: Theme.Size.minTouch)
            .padding(.horizontal, Theme.Spacing.screen)

            TabView(selection: $page) {
                welcome.tag(0)
                values.tag(1)
                modePage.tag(2)
                ready.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pageCount, current: page)
                .padding(.bottom, Theme.Spacing.l)

            PrimaryButton(page == pageCount - 1 ? OnboardingContent.startTitle : "次へ") {
                if page < pageCount - 1 {
                    withAnimation(.spring(duration: 0.35)) { page += 1 }
                } else {
                    finish()
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.s)
        }
        .background(Theme.Palette.background)
        .onAppear { if page == pageCount - 1 { stamped = true } }
        .onChange(of: page) { _, newValue in
            Haptics.selection()
            stamped = false
            if newValue == pageCount - 1 {
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    stamped = true
                }
            }
        }
    }

    // MARK: - ページ

    /// 1ページ目: アプリ名と一言だけ
    private var welcome: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image("ChasenSide").resizable().scaledToFit().frame(height: 200)
            VStack(spacing: Theme.Spacing.s) {
                Text(OnboardingContent.appName)
                    .font(.dsTitle)
                    .foregroundStyle(Theme.Palette.text)
                Text(OnboardingContent.tagline)
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }

    /// 2ページ目: できることを3行で
    private var values: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text(OnboardingContent.valuesTitle)
                .font(.dsTitle)
                .foregroundStyle(Theme.Palette.text)
                .padding(.bottom, Theme.Spacing.l)
            ForEach(OnboardingContent.values, id: \.title) { item in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: item.symbol)
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.text)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.text)
                        Text(item.detail)
                            .font(.dsCaption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                }
                .padding(.vertical, Theme.Spacing.m)
                .accessibilityElement(children: .combine)
                Rectangle().fill(Theme.Palette.separator).frame(height: 1)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    /// 3ページ目: 点て方を選ぶ(あとで設定から変えられる)
    private var modePage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Spacer()
            Text("たて方と茶碗を選んでください")
                .font(.dsTitle)
                .foregroundStyle(Theme.Palette.text)
            Text("あとから設定で変えられます。")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
            ModePicker(selection: $mode)
            Text("茶碗")
                .font(.dsSection)
                .foregroundStyle(Theme.Palette.secondaryText)
                .padding(.top, Theme.Spacing.s)
            ChawanPicker(selection: $style)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    /// 4ページ目: 判子が押されて「準備完了」
    private var ready: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            ChawanView(foam: stamped ? 1 : 0, smoothness: 1, size: 140)
            VStack(spacing: Theme.Spacing.s) {
                Text(OnboardingContent.readyTitle)
                    .font(.dsTitle)
                    .foregroundStyle(Theme.Palette.text)
                Text(OnboardingContent.readyMessage)
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        Haptics.success()
        onFinish()
    }
}

/// いまのページを示す点。今のページだけ横に長くして、色だけに頼らず形でも示す。
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.Palette.text : Theme.Palette.separator)
                    .frame(width: index == current ? 20 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.3), value: current)
        .accessibilityElement()
        .accessibilityLabel("\(count)ページ中\(current + 1)ページ目")
    }
}

/// オンボーディングの文言。案が決まったらここだけ書き換える。
enum OnboardingContent {
    static let appName = "おてまえ"
    static let stampText = "渋"
    static let tagline = "渋々でいい。\n一杯たてたら、渋い時間が始まる。"
    static let valuesTitle = "使い方の流れ"
    static let values: [(symbol: String, title: String, detail: String)] = [
        ("drop", "ししおどしで、区切る", "SNSを見すぎたら「カコン」。茶室へご案内します。"),
        ("hand.wave", "振って、抹茶をたてる", "スマホを振って抹茶をたて、ひと息ついて、次にやることを決める。"),
        ("circle.dotted", "うら返して、石うすを回す", "うら返している間だけ抹茶がひける。ひいた抹茶で次の一杯を。"),
    ]
    static let readyTitle = "どうぞ、お入りください"
    static let readyMessage = "まずは、おもてなしの一杯から。"
    static let startTitle = "茶室に入る"
}

#Preview {
    OnboardingView(onFinish: {})
}
