import DesignSystem
import SwiftUI

/// 体験の流れ。入口 → (SNSの区切り) → 一服 → 石臼 → 次の一服 → …
enum Stage: Equatable {
    case entrance
    case sns
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
            case .sns:
                SNSView(go: go)
            case .ippuku:
                IppukuView(motion: motion, go: go)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.5), value: scene)
        .onOpenURL { url in if url.host() == "sns" { go(.sns) } }
        // 抹茶をたてている間だけ、鳥のさえずりを流す(フェードで出入り)
        .onChange(of: scene, initial: true) { _, now in
            if now == .ippuku { SoundBank.shared.startAmbient() } else { SoundBank.shared.stopAmbient() }
        }
        // 起動引数 `-scene sns|ippuku` で場面を指定して開ける(画面確認・デモ準備用)
        .task {
            switch UserDefaults.standard.string(forKey: "scene") {
            case "sns": scene = .sns
            case "ippuku": scene = .ippuku
            default: break
            }
        }
    }

    private func go(_ next: Stage) {
        withAnimation(.easeInOut(duration: 0.5)) { scene = next }
    }
}

/// ホーム。やることは1つ「抹茶をたてて、集中する」だけ。
/// 上に今日たてた杯数と今週の記録、ランクを小さく。くわしい記録は左上から(段階的に見せる)。
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
                    Text(today.isEmpty ? "今日はまだです" : "今日いちばんの集中度 \(today.map(\.score).max() ?? 0)")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xl)
                .accessibilityElement(children: .combine)

                // 今週(月〜日)。たてた日に色がつく。休んでも何も減らない
                Button { showsHistory = true } label: {
                    VStack(spacing: Theme.Spacing.m) {
                        WeekRow(days: record.servedDays)
                        RankProgress(total: record.totalPoints)
                    }
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
                    .contentShape(.rect)
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, Theme.Spacing.xl)
                .accessibilityHint("押すと、くわしい記録が見られます")

                // 今日決めた「やること」があれば、かけじくで
                if let last = record.servings.last, Calendar.current.isDateInToday(last.date), !last.ichiji.isEmpty {
                    SectionHeader("今日やること")
                    HStack {
                        Spacer()
                        KakejikuView(text: last.ichiji, height: 200)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.m)
                }
            } bottom: {
                PrimaryButton("抹茶をたてる", systemImage: "cup.and.saucer") { go(.ippuku) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsHistory = true } label: {
                        Image(systemName: "chart.bar")
                            .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                    }
                    .accessibilityLabel("記録")
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

/// 今週の7日(月〜日)。たてた日は抹茶色、今日は輪で示す
struct WeekRow: View {
    let days: Set<Date>

    var body: some View {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        return HStack {
            ForEach(0..<7, id: \.self) { d in
                let date = cal.date(byAdding: .day, value: d, to: start) ?? start
                let done = days.contains(date)
                VStack(spacing: Theme.Spacing.xs) {
                    Text(labels[d])
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    ZStack {
                        Circle().fill(done ? Theme.Palette.matcha : Theme.Palette.separator.opacity(date > today ? 0.4 : 1))
                        if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.Palette.shiro) }
                    }
                    .frame(width: 26, height: 26)
                    .overlay { if date == today { Circle().stroke(Theme.Palette.text, lineWidth: 1.5).padding(-3) } }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("今週は \(days.filter { $0 >= start }.count) 日、抹茶をたてました")
    }
}
