import DesignSystem
import SwiftUI

/// 体験の流れ。入口 → (SNSの区切り) → 一服 → 石臼 → 次の一服 → …
enum Stage: Equatable {
    case entrance
    case sns
    case ippuku
    case ishiusu
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
            case .sns:
                SNSView(go: go)
            case .ippuku:
                IppukuView(motion: motion, go: go)
            case .ishiusu:
                IshiusuScreen(motion: motion, go: go)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: scene)
        .onOpenURL { url in if url.host() == "sns" { go(.sns) } }
        // 起動引数 `-scene sns|ippuku|ishiusu` で場面を指定して開ける(画面確認・デモ準備用)
        .task {
            switch UserDefaults.standard.string(forKey: "scene") {
            case "sns": scene = .sns
            case "ippuku": scene = .ippuku
            case "ishiusu": scene = .ishiusu
            default: break
            }
        }
    }

    private func go(_ next: Stage) {
        withAnimation(.easeInOut(duration: 0.5)) { scene = next }
    }
}

/// 茶室の入口(ホーム)。今日取り戻した杯数・茶壺・最新の掛け軸。
struct EntranceView: View {
    @Environment(TeaStore.self) private var store
    let go: (Stage) -> Void
    @State private var showsHistory = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            DSScreen("渋分") {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("今日は")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text("抹茶")
                            .font(.headline)
                        Text("\(store.record.cupsToday())")
                            .font(.dsHero)
                            .contentTransition(.numericText())
                        Text("杯ぶん")
                            .font(.headline)
                    }
                    .foregroundStyle(Theme.Palette.text)
                    Text("取り戻しました")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
                .accessibilityElement(children: .combine)

                Button { showsHistory = true } label: {
                    RankProgress(total: store.record.totalPoints)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.top, Theme.Spacing.l)
                }
                .buttonStyle(.plain)

                SectionHeader("茶壺")
                HStack(spacing: Theme.Spacing.m) {
                    ChawanView(foam: 0, size: 44)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(store.record.matchaCups > 0 ? "自分で挽いた抹茶が \(store.record.matchaCups)杯" : "次の一服は、おもてなしの一杯")
                            .font(.dsBody)
                            .foregroundStyle(Theme.Palette.text)
                        Text("これまで石臼を回した時間 \(Self.hours(store.record.groundSeconds))")
                            .font(.dsCaption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.m)
                .accessibilityElement(children: .combine)

                if let ichiji = store.record.latestIchiji {
                    SectionHeader("最近の掛け軸")
                    HStack {
                        Spacer()
                        KakejikuView(text: ichiji, height: 220)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.m)
                }
            } bottom: {
                VStack(spacing: Theme.Spacing.s) {
                    PrimaryButton("一服する", systemImage: "cup.and.saucer") { go(.ippuku) }
                    Button("SNSを見ているところから試す") { go(.sns) }
                        .font(.dsCaption.weight(.medium))
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .frame(minHeight: Theme.Size.minTouch)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsHistory = true } label: {
                        Image(systemName: "chart.bar")
                            .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                    }
                    .accessibilityLabel("茶の記録")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsSettings = true } label: {
                        Image(systemName: "gearshape")
                            .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                    }
                    .accessibilityLabel("設定")
                }
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
