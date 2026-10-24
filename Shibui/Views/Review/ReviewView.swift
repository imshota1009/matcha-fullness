import DesignSystem
import SwiftData
import SwiftUI

/// 振り返り。1日を24時間の円(ダイヤル)で表す(SPEC 5章 F)。
/// 真上が 0:00 で時計回り。点てた時刻は縁の外側に抹茶色の点、タイマーで集中した時間は縁の内側の帯を藍で塗る。
/// 前日/翌日はボタンと横スワイプの両方で切り替え、「今日」へいつでも戻れる。下に今月のカレンダー。
struct ReviewView: View {
    @Query(sort: \MatchaSession.startedAt) private var matcha: [MatchaSession]
    @Query(sort: \FocusSession.startedAt) private var focus: [FocusSession]
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var selected: MatchaSession?

    private var cal: Calendar { .current }
    private var isToday: Bool { cal.isDateInToday(day) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    dayBar
                    DayDial(day: day, matcha: dayMatcha, focus: focus) { selected = $0 }
                        .frame(height: 340)
                        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                            if v.translation.width < -60 { move(1) } else if v.translation.width > 60 { move(-1) }
                        })
                    legend
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("今月の記録").font(.headline).foregroundStyle(Theme.Palette.text)
                        MonthCalendar(days: Set(matcha.map { cal.startOfDay(for: $0.startedAt) }))
                            .padding(Theme.Spacing.m)
                            .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
                    }
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.l)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.Palette.background)
            .navigationTitle("振り返り")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selected) { s in SessionDetailSheet(session: s) }
        }
    }

    private var dayMatcha: [MatchaSession] { matcha.filter { cal.isDate($0.startedAt, inSameDayAs: day) } }

    private var dayBar: some View {
        HStack {
            FlatCircleButton(systemImage: "chevron.left", label: "前の日") { move(-1) }
            Spacer()
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.month().day().weekday()))
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                if !isToday {
                    Button("今日へ戻る") { withAnimation { day = cal.startOfDay(for: .now) } }
                        .font(.dsCaption)
                        .frame(minHeight: Theme.Size.minTouch)
                }
            }
            Spacer()
            FlatCircleButton(systemImage: "chevron.right", label: "次の日") { move(1) }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.l) {
            Label { Text("点てた時刻") } icon: { Circle().fill(Theme.Palette.matcha).frame(width: 10, height: 10) }
            Label { Text("集中した時間") } icon: { Capsule().fill(Theme.Palette.ai).frame(width: 18, height: 8) }
        }
        .font(.dsCaption)
        .foregroundStyle(Theme.Palette.secondaryText)
    }

    private func move(_ d: Int) {
        guard let next = cal.date(byAdding: .day, value: d, to: day), next <= cal.startOfDay(for: .now) else { return }
        Haptics.selection()
        withAnimation(.snappy) { day = next }
    }
}

/// 24時間のダイヤル
struct DayDial: View {
    let day: Date
    let matcha: [MatchaSession]
    let focus: [FocusSession]
    let onTap: (MatchaSession) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = size / 2 - 44          // 基準の円(縁)
            let points = placedPoints(center: c, radius: r)
            ZStack {
                Canvas { ctx, _ in
                    // 1. 時刻の目盛り(1時間ごと)と 0・6・12・18 の数字
                    for h in 0..<24 {
                        let a = Double(h) / 24 * 2 * .pi
                        let long = h % 6 == 0
                        var p = Path()
                        p.move(to: pt(c, r + 14, a))
                        p.addLine(to: pt(c, r + (long ? 24 : 19), a))
                        ctx.stroke(p, with: .color(Theme.Palette.secondaryText), lineWidth: long ? 2 : 1)
                        if long {
                            ctx.draw(Text("\(h)").font(.caption.monospacedDigit()).foregroundStyle(Theme.Palette.secondaryText), at: pt(c, r + 36, a))
                        }
                    }
                    // 3. 基準の円(縁)
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(Theme.Palette.separator), lineWidth: 1.5)
                    // 4. 集中の帯(縁の内側のドーナツ)
                    let band = 22.0, inner = r - 6 - band / 2
                    for (s, e) in focusRanges() {
                        var p = Path()
                        p.addArc(center: c, radius: inner, startAngle: .radians(s - .pi / 2), endAngle: .radians(e - .pi / 2), clockwise: false)
                        ctx.stroke(p, with: .color(Theme.Palette.ai), style: StrokeStyle(lineWidth: band, lineCap: .butt))
                    }
                    // 2. 抹茶の点
                    for (_, p) in points {
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(Theme.Palette.matcha))
                    }
                }
                // 点は小さいので、タップできる範囲は 44pt とる
                ForEach(points, id: \.0.id) { s, p in
                    Button { onTap(s) } label: { Color.clear.frame(width: 44, height: 44).contentShape(.circle) }
                        .position(p)
                        .accessibilityLabel("\(s.startedAt.formatted(.dateTime.hour().minute()))に点てた。集中の目安 \(s.score)")
                }
                // 5. 中央: 日付とその日の合計
                VStack(spacing: Theme.Spacing.xs) {
                    Text(day.formatted(.dateTime.month().day()))
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text("点てた回数 \(matcha.count)回")
                    Text("集中 \(Self.duration(totalFocus()))")
                }
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.text)
                .position(c)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func pt(_ c: CGPoint, _ r: Double, _ a: Double) -> CGPoint {
        CGPoint(x: c.x + r * sin(a), y: c.y - r * cos(a))
    }

    private func angle(_ d: Date) -> Double {
        d.timeIntervalSince(day) / 86_400 * 2 * .pi
    }

    /// 点の位置。基準の円のすぐ外側。時刻が近くて重なるときは、外側へ1段ずつずらす
    private func placedPoints(center c: CGPoint, radius r: Double) -> [(MatchaSession, CGPoint)] {
        var placed: [(MatchaSession, Double, Int)] = []
        for s in matcha.sorted(by: { $0.startedAt < $1.startedAt }) {
            let a = angle(s.startedAt)
            var ring = 0
            while placed.contains(where: { $0.2 == ring && abs($0.1 - a) * r < 13 }) { ring += 1 }
            placed.append((s, a, ring))
        }
        return placed.map { s, a, ring in (s, pt(c, r + 7 + Double(min(ring, 2)) * 13, a)) }
    }

    /// その日の集中の範囲(角度)。日をまたぐ記録は 0:00 で切る
    private func focusRanges() -> [(Double, Double)] {
        let end = day.addingTimeInterval(86_400)
        return focus.compactMap { f in
            let s = max(f.startedAt, day), e = min(f.endedAt, end)
            guard e > s else { return nil }
            return (angle(s), angle(e))
        }
    }

    private func totalFocus() -> TimeInterval {
        focusRanges().reduce(0) { $0 + ($1.1 - $1.0) / (2 * .pi) * 86_400 }
    }

    static func duration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return m >= 60 ? "\(m / 60)時間\(m % 60)分" : "\(m)分"
    }
}

/// その回の詳細(シート)。スコアの内訳とメッセージ。スワイプで閉じる
struct SessionDetailSheet: View {
    let session: MatchaSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("集中の目安", value: "\(session.score)")
                    LabeledContent("泡", value: FoamStage.names[min(3, session.foamStage)])
                } header: {
                    Text(session.startedAt.formatted(.dateTime.month().day().hour().minute()))
                }
                Section("内訳") {
                    LabeledContent("泡スコア", value: "\(session.foamScore)")
                    LabeledContent("直線性", value: "\(session.lineScore)")
                    LabeledContent("リズム", value: "\(session.rhythmScore)")
                    LabeledContent("量", value: "\(session.countScore)")
                    LabeledContent("仕上げ", value: "\(session.finishScore)")
                    LabeledContent("回す", value: "\(session.rotateScore)")
                }
                Section("メッセージ") {
                    Text(Messages.text(session.messageID))
                }
                Section {
                    Button("この記録を消す", systemImage: "trash", role: .destructive) {
                        context.delete(session)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background)
            .navigationTitle("この一杯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
