import DesignSystem
import SwiftUI

/// 体験の流れ。ホーム → 一杯(点てる → 結果)→ ホーム
enum Stage: Equatable {
    case entrance
    case ippuku
}

/// アプリの土台。いまの場面を切り替えて見せる。どの場面からも入口へ戻れる(脱出性)。
struct RootView: View {
    @Environment(TeaStore.self) private var store
    @State private var scene: Stage = .entrance
    @State private var motion = MotionService()

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()
            switch scene {
            case .entrance:
                EntranceView(go: go)
            case .ippuku:
                IppukuView(motion: motion, go: go)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: scene)
        // 起動引数 `-scene ippuku` で点てる画面から開ける(画面確認・デモ準備用)
        .task { if UserDefaults.standard.string(forKey: "scene") == "ippuku" { scene = .ippuku } }
    }

    private func go(_ next: Stage) {
        withAnimation(.easeInOut(duration: 0.5)) { scene = next }
    }
}

/// ホーム。やることは1つ「抹茶をたてて、集中する」だけ。
/// 今日たてた杯数と、今日いちばんの集中の目安。くわしい記録は左上から(段階的に見せる)。
struct EntranceView: View {
    @Environment(TeaStore.self) private var store
    let go: (Stage) -> Void
    @State private var showsHistory = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            DSScreen("おてまえ") {
                let record = store.record
                // 今日たてた杯数(いちばん大事な数字)と、今日いちばんの集中度
                let today = record.servings.filter { Calendar.current.isDateInToday($0.date) }
                VStack(spacing: Theme.Spacing.xs) {
                    Text("今日たてた抹茶")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text("\(today.count)")
                            .font(.dsHero)
                            .contentTransition(.numericText())
                        Text("杯")
                            .font(.headline)
                    }
                    .foregroundStyle(Theme.Palette.text)
                    Text(today.isEmpty ? "今日はまだです" : "今日いちばんの集中の目安 \(today.map(\.score).max() ?? 0)")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
                .accessibilityElement(children: .combine)

            } bottom: {
                PrimaryButton("抹茶をたてる", systemImage: "cup.and.saucer") { go(.ippuku) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    FlatCircleButton(systemImage: "chart.bar", label: "記録") { showsHistory = true }
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    FlatCircleButton(systemImage: "gearshape", label: "設定") { showsSettings = true }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            // 起動引数 `-sheet history|settings` で開いた状態にできる(画面確認用)
            .task {
                switch UserDefaults.standard.string(forKey: "sheet") {
                case "history": showsHistory = true
                case "settings": showsSettings = true
                default: break
                }
            }
            .sheet(isPresented: $showsHistory) { HistoryView() }
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    static func hours(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        return m >= 60 ? "\(m / 60)時間\(m % 60)分" : "\(m)分"
    }
}

/// 場面の左上に置く「入口へ戻る」。どこからでも1回で抜けられる。
struct BackToEntrance: View {
    let go: (Stage) -> Void
    var body: some View {
        Button { go(.entrance) } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                .contentShape(.rect)
        }
        .accessibilityLabel("入口へ戻る")
    }
}
