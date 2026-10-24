import DesignSystem
import SwiftData
import SwiftUI

/// アプリの土台。画面下部のタブバー(点てる / 振り返り / 設定)。iOS 標準の TabView。
struct MainTabView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("点てる", systemImage: "cup.and.saucer") { WaitingView() }
            Tab("振り返り", systemImage: "clock") { ReviewView() }
            Tab("設定", systemImage: "gearshape") { SettingsView() }
        }
        .task { LegacyImport.run(into: context) }
    }
}

/// 点てる(待機)。入口。今日の回数と「点てる」ボタン。
/// 点てる(本体)は全画面で開く(タブバーを隠す)。
struct WaitingView: View {
    @Query(sort: \MatchaSession.startedAt) private var sessions: [MatchaSession]
    @State private var flowOpen = false
    /// 結果を「閉じる」で戻ってきたときの一言
    @State private var parting = false

    var body: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                Spacer()
                RikyuView(size: 200, mood: parting ? 1 : 0)
                if parting {
                    Text("スマホを置いて、目の前のことへ")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.Palette.text)
                        .transition(.opacity)
                } else {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("作業の前に、一杯の儀式を")
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(Theme.Palette.text)
                        Text(today.isEmpty ? "今日はまだ点てていません" : "今日 \(today.count)杯 点てました")
                            .font(.dsCaption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                }
                Spacer()
                PrimaryButton("点てる", systemImage: "cup.and.saucer") { flowOpen = true }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.m)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.background)
            .navigationTitle("点てる")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $flowOpen) {
            TeaFlowView { closedWithParting in
                flowOpen = false
                if closedWithParting { showParting() }
            }
        }
        // 起動引数 `-scene ippuku` で点てる画面から開ける(画面確認・デモ準備用)
        .task { if UserDefaults.standard.string(forKey: "scene") == "ippuku" { flowOpen = true } }
    }

    private func showParting() {
        withAnimation { parting = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { parting = false }
        }
    }
}
