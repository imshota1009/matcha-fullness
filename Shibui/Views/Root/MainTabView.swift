import DesignSystem
import SwiftData
import SwiftUI

/// アプリの土台。画面下部のタブバー(点てる / 振り返り / 設定)。iOS 標準の TabView。
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @State private var tab = 0
    private let reminders = Reminders.shared

    var body: some View {
        TabView(selection: $tab) {
            Tab("点てる", systemImage: "cup.and.saucer", value: 0) { WaitingView() }
            Tab("振り返り", systemImage: "clock", value: 1) { ReviewView() }
            Tab("設定", systemImage: "gearshape", value: 2) { SettingsView() }
        }
        .task { LegacyImport.run(into: context) }
        // 通知をタップして開いたら、点てるタブへ(点てる画面は WaitingView が開く)
        .onChange(of: reminders.openTemae, initial: true) { _, open in if open { tab = 0 } }
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
                // 小さな茶室(床の間・畳・奥の壁)の前に、りきゅうさんが座る。お雛様の飾り台のように、背中のまわりだけ
                ZStack(alignment: .bottom) {
                    ChashitsuBackdrop()
                        .frame(width: 300, height: 250)
                    RikyuView(size: 210, mood: parting ? 1 : 0)
                        .offset(y: 26)
                }
                .frame(width: 300, height: 260)
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
                RankBar(points: sessions.reduce(0) { $0 + $1.score })
                    .padding(.horizontal, Theme.Spacing.xl)
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
        // 通知をタップして開いたら、点てる(本体)を直接開く
        .onChange(of: Reminders.shared.openTemae, initial: true) { _, open in
            guard open else { return }
            Reminders.shared.openTemae = false
            flowOpen = true
        }
        // 起動引数 `-scene ippuku` で点てる画面から開ける(画面確認・デモ準備用)
        .task { if ["ippuku", "timer"].contains(UserDefaults.standard.string(forKey: "scene")) { flowOpen = true } }
    }

    private func showParting() {
        withAnimation { parting = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { parting = false }
        }
    }
}
