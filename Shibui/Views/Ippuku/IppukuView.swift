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
                TemaeView(motion: motion) { s in finish(score: s) }
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
        .animation(.easeInOut(duration: 0.4), value: session?.id)
        .onAppear { startedAt = .now }
    }

    private func finish(score s: Int) {
        let usedToday = Set(sessions.filter { Calendar.current.isDateInToday($0.startedAt) }.map(\.messageID))
        let new = MatchaSession(startedAt: startedAt, score: s, foamScore: s, foamStage: FoamStage.of(s),
                                messageID: Messages.pick(at: startedAt, usedToday: usedToday))
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

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            ChawanView(foam: 1, smoothness: Double(session.foamStage) / 3, size: 140)
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
            Text(Messages.text(session.messageID))
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.center)
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
        }
    }
}
