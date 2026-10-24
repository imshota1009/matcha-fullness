import DesignSystem
import SwiftUI

/// ホーム。上に「見送って浮いたお金」、中に軒下(吊るした柿)と一覧、下部に「吊るす」。
/// Mobbin の Cash App(中央の大きな金額+黒い主ボタン)と Klarna(名前と値段の1行リスト)を参考にした。
struct HomeView: View {
    @Environment(KakiStore.self) private var store
    @AppStorage("didOnboard") private var didOnboard = true
    @State private var showsHang = false
    @State private var deciding: Kaki?

    var body: some View {
        // 1秒ごとに描き直し、柿が熟していく様子をその場で見せる
        TimelineView(.periodic(from: .now, by: 1)) { context in
            DSScreen("ほしいも") {
                hero
                eaves(now: context.date)
                hangingList(now: context.date)
                decidedList
            } bottom: {
                VStack(spacing: Theme.Spacing.s) {
                    if store.lastRemoved != nil { undoBar }
                    PrimaryButton("欲しい物を吊るす", systemImage: "plus") { showsHang = true }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("はじめの説明をもう一度見る", systemImage: "book") { didOnboard = false }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                }
                .accessibilityLabel("その他")
            }
        }
        // ウィジェットなどからのリンク: shibui://hang で吊るす画面、shibui://ripe で食べごろの1つ目を開く
        .onOpenURL { open($0.host()) }
        // 起動引数 `-open hang` / `-open ripe` でも同じ画面を開ける(画面確認・デモ準備用)
        .task { open(UserDefaults.standard.string(forKey: "open")) }
        .sheet(isPresented: $showsHang) { HangSheet() }
        .sheet(item: $deciding) { kaki in DecideSheet(kaki: kaki) }
        .animation(.spring(duration: 0.35), value: store.kakis)
        .animation(.spring(duration: 0.3), value: store.lastRemoved)
    }

    private func open(_ target: String?) {
        switch target {
        case "hang": showsHang = true
        case "ripe": deciding = store.hanging.first { $0.isRipe() } ?? store.hanging.first
        default: break
        }
    }

    // MARK: - 浮いたお金

    private var hero: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("見送って、浮いたお金")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
            Text(store.savedAmount.yen)
                .font(.dsHero)
                .foregroundStyle(Theme.Palette.text)
                .contentTransition(.numericText(value: Double(store.savedAmount)))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 軒下

    /// ひもに吊るした柿が並ぶ。押すと柿の画面へ
    private func eaves(now: Date) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Palette.text.opacity(0.75))
                .frame(height: 3)
            if store.hanging.isEmpty {
                Text("軒下は空です。欲しい物を吊るしてみましょう。")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.vertical, Theme.Spacing.l)
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ForEach(store.hanging.prefix(5)) { kaki in
                        Button { deciding = kaki } label: {
                            DryView(kind: kaki.kind, ripeness: kaki.ripeness(at: now), size: 52, showsString: true)
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityLabel("\(kaki.name)、\(kaki.isRipe(at: now) ? "食べごろです" : "干している途中")")
                    }
                }
                .padding(.bottom, Theme.Spacing.s)
            }
        }
        .padding(.top, Theme.Spacing.l)
    }

    // MARK: - 干している

    @ViewBuilder
    private func hangingList(now: Date) -> some View {
        if !store.hanging.isEmpty {
            SectionHeader("干している")
            LazyVStack(spacing: 0) {
                ForEach(store.hanging) { kaki in
                    Button { deciding = kaki } label: {
                        KakiRow(kaki: kaki, now: now)
                    }
                    .buttonStyle(PressScaleStyle())
                    Rectangle().fill(Theme.Palette.separator).frame(height: 1)
                }
            }
        }
    }

    // MARK: - 決めたもの

    @ViewBuilder
    private var decidedList: some View {
        if !store.decided.isEmpty {
            SectionHeader("決めたもの")
            LazyVStack(spacing: 0) {
                ForEach(store.decided.prefix(10)) { kaki in
                    HStack(spacing: Theme.Spacing.m) {
                        Text(kaki.name)
                            .font(.dsBody)
                            .foregroundStyle(Theme.Palette.secondaryText)
                            .strikethrough(kaki.decision == .passed, color: Theme.Palette.secondaryText)
                        Spacer()
                        Text(kaki.price.yen)
                            .font(.dsCaption.monospacedDigit())
                            .foregroundStyle(Theme.Palette.secondaryText)
                        StatusLabel(kaki.decision == .passed ? "見送り" : "購入", kind: kaki.decision == .passed ? .positive : .neutral)
                    }
                    .padding(.vertical, Theme.Spacing.m)
                    .frame(minHeight: Theme.Size.minTouch)
                    .accessibilityElement(children: .combine)
                    Rectangle().fill(Theme.Palette.separator).frame(height: 1)
                }
            }
        }
    }

    private var undoBar: some View {
        HStack {
            Text("軒下から降ろしました")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button("元に戻す") {
                Haptics.selection()
                store.undoRemove()
            }
            .font(.dsCaption.weight(.semibold))
            .frame(minHeight: Theme.Size.minTouch)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// 一覧の1行。柿の絵・名前・値段・残り時間。食べごろになったら朱色で知らせる。
struct KakiRow: View {
    let kaki: Kaki
    let now: Date

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            DryView(kind: kaki.kind, ripeness: kaki.ripeness(at: now), size: 36)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(kaki.name)
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.text)
                Text(kaki.price.yen)
                    .font(.dsCaption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            if kaki.isRipe(at: now) {
                StatusLabel("食べごろ", kind: .alert)
            } else {
                Text(RemainingText.make(until: kaki.ripeAt, now: now))
                    .font(.dsCaption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(minHeight: Theme.Size.minTouch)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// 「あと2日」「あと5時間」「あと40秒」
enum RemainingText {
    static func make(until date: Date, now: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        if s >= 86_400 { return "あと\(s / 86_400)日" }
        if s >= 3_600 { return "あと\(s / 3_600)時間" }
        if s >= 60 { return "あと\(s / 60)分" }
        return "あと\(s)秒"
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(KakiStore())
}
