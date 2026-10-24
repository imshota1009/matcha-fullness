import DesignSystem
import SwiftData
import SwiftUI

/// 一杯の流れ(全画面)。点てる(本体)→ 結果 →(閉じる / タイマー)。
/// 点てる(本体)には「やめる」を置く。やめた回は記録しない(脱出性)。
struct TeaFlowView: View {
    /// 終わったとき。true なら「閉じる」で戻った(待機画面で一言出す)
    let onDone: (_ closedWithParting: Bool) -> Void
    @Environment(\.modelContext) private var context
    @Query(sort: \MatchaSession.startedAt) private var sessions: [MatchaSession]
    @State private var motion = MotionService()
    @State private var startedAt = Date()
    @State private var session: MatchaSession?
    @State private var timerOpen = false
    /// 茶碗が出る前に、襖が開く
    @State private var doorsOpen = false

    var body: some View {
        ZStack {
            if timerOpen {
                FocusTimerView(matchaID: session?.id) { onDone(false) }
                    .transition(.opacity)
            } else if let session {
                ResultView(session: session, onClose: { onDone(true) }, onTimer: { withAnimation { timerOpen = true } })
                    .transition(.opacity)
            } else {
                // 画面いっぱいの 3D の茶碗(真上から)
                TemaeView(motion: motion) { r in finish(r) }
                    .overlay(alignment: .topLeading) {
                        Button { onDone(false) } label: {
                            Text("やめる")
                                .font(.headline)
                                .foregroundStyle(Theme.Palette.text)
                                .padding(.horizontal, Theme.Spacing.m)
                                .frame(minHeight: Theme.Size.minTouch)
                                .background(Theme.Palette.shiro, in: .capsule)
                        }
                        .padding(.leading, Theme.Spacing.m)
                        .accessibilityHint("記録せずに、点てるのをやめます")
                    }
                    .transition(.opacity)
            }
        }
        .overlay { if !doorsOpen { FusumaOpening { doorsOpen = true } } }
        .animation(.easeInOut(duration: 0.4), value: session?.id)
        .onAppear {
            startedAt = .now
            // 起動引数 `-scene timer` でタイマーから始める(画面確認用)
            if UserDefaults.standard.string(forKey: "scene") == "timer" { doorsOpen = true; timerOpen = true }
        }
    }

    private func finish(_ r: TemaeResult) {
        let usedToday = Set(sessions.filter { Calendar.current.isDateInToday($0.startedAt) }.map(\.messageID))
        let new = MatchaSession(startedAt: startedAt, score: r.score, foamScore: r.foam, lineScore: r.line, rhythmScore: r.rhythm,
                                countScore: r.count, finishScore: r.finish, rotateScore: r.rotate, foamStage: FoamStage.of(r.foam),
                                messageID: Messages.pick(at: startedAt, usedToday: usedToday))
        new.meanSide = r.meanSide
        new.cv = r.cv
        new.strokes = r.strokes
        context.insert(new)
        try? context.save()
        Haptics.success()
        session = new
    }
}

/// 結果。所作スコア(集中の目安)、泡の段階、時間帯のメッセージ。「閉じる」と「タイマー」を選ぶ。
struct ResultView: View {
    let session: MatchaSession
    let onClose: () -> Void
    let onTimer: () -> Void
    @State private var shown = 0
    @Query private var sessions: [MatchaSession]

    /// これまでの点の合計(この一杯を含む)と、この一杯の前の合計
    private var points: Int { sessions.reduce(0) { $0 + $1.score } }
    private var before: Int { points - session.score }
    private var promoted: Bool { Rank.current(for: points) != Rank.current(for: before) }
    /// お点前の講評(はじめは定型文、AI ができたら差しかえる)
    @State private var kouhyou: Kouhyou?
    @State private var byAI = false

    private var kouhyouInput: KouhyouInput {
        let previous = sessions.filter { $0.startedAt < session.startedAt }.max { $0.startedAt < $1.startedAt }?.score
        return KouhyouInput(meanSide: session.meanSide, cv: session.cv, strokes: session.strokes, foam: session.foamScore,
                            finish: session.finishScore, rotate: session.rotateScore, total: session.score, previous: previous)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            // 抹茶の缶(Unity で作った絵。本物らしく見えるよう、この絵だけ陰影をつけている)
            Image("TeaCan")
                .resizable()
                .scaledToFit()
                .frame(height: 170)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(shown)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                Text("集中の目安")
                    .font(.headline)
            }
            .foregroundStyle(Theme.Palette.text)
            Text("泡: \(FoamStage.names[session.foamStage])")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
            // お点前の講評(5章 L-6)
            if let k = kouhyou {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(k.review)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.Palette.text)
                    Label(k.goodPoint, systemImage: "circle.circle")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.matcha)
                    Label(k.nextFocus, systemImage: "arrow.forward.circle")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
                .padding(.horizontal, Theme.Spacing.screen)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("講評。\(k.review)。良かった点、\(k.goodPoint)。次に意識すること、\(k.nextFocus)")
            }
            Text(Messages.text(session.messageID))
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
            RankBar(points: points, gained: session.score, promoted: promoted)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
            Text("スコアは所作のていねいさから出した目安です(根拠は調査中)")
                .font(.caption2)
                .foregroundStyle(Theme.Palette.secondaryText)
            Spacer()
            HStack(spacing: Theme.Spacing.s) {
                Button(action: onClose) {
                    Text("閉じる")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                        .background(Theme.Palette.surface, in: .capsule)
                }
                .buttonStyle(PressScaleStyle())
                Button(action: onTimer) {
                    Label("タイマー", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.shiro)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                        .background(Theme.Palette.ai, in: .capsule)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, Theme.Spacing.s)
        }
        .background(Theme.Palette.background)
        .task {
            for value in stride(from: 0, through: session.score, by: max(1, session.score / 30)) {
                withAnimation(.snappy(duration: 0.04)) { shown = value }
                try? await Task.sleep(for: .milliseconds(25))
            }
            withAnimation { shown = session.score }
            Haptics.impact()
            if promoted { Haptics.success() }
        }
        .task {
            // まず数値から決まる定型文をすぐ出し、端末内の AI の講評ができたら差しかえる(画面は待たせない)
            if let saved = session.review, let g = session.goodPoint, let n = session.nextFocus {
                kouhyou = Kouhyou(review: saved, goodPoint: g, nextFocus: n)
                return
            }
            withAnimation { kouhyou = KouhyouMaker.fallback(kouhyouInput) }
            if let ai = await KouhyouMaker.generate(kouhyouInput) {
                withAnimation { kouhyou = ai; byAI = true }
                session.review = ai.review
                session.goodPoint = ai.goodPoint
                session.nextFocus = ai.nextFocus
            }
        }
    }
}

/// ランクと、次のランクまでの進み具合。上がったときは「昇格」と出す
struct RankBar: View {
    let points: Int
    var gained: Int? = nil
    var promoted = false

    var body: some View {
        let rank = Rank.current(for: points)
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(promoted ? "昇格 \(rank.name)" : rank.name)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(promoted ? Theme.Palette.matcha : Theme.Palette.text)
                Text(rank.tier)
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
                if let gained { Text("+\(gained)点").font(.dsCaption.monospacedDigit()).foregroundStyle(Theme.Palette.matcha) }
            }
            ProgressView(value: Rank.progress(for: points))
                .tint(Theme.Palette.matcha)
            Text(Rank.next(for: points).map { "次の「\($0.name)」まで \($0.threshold - points)点" } ?? "最上位です")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
