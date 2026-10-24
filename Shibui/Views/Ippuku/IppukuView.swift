import DesignSystem
import SwiftUI

/// 一杯の流れ。点てる(TemaeView)→ 結果。結果の「閉じる」でホームへ戻る。
/// 左上の x でいつでも抜けられる(脱出性)。やめた回は記録しない。
struct IppukuView: View {
    @Environment(TeaStore.self) private var store
    let motion: MotionService
    let go: (Stage) -> Void

    @State private var score: Int?

    var body: some View {
        Group {
            if let score {
                ResultView(score: score, praise: TemaeJudge.praise(for: score)) { go(.entrance) }
                    .transition(.opacity)
            } else {
                // 画面いっぱいの 3D の茶碗(真上から)
                TemaeView(motion: motion) { s in finish(score: s) }
                    .overlay(alignment: .topLeading) { BackToEntrance(go: go).padding(.leading, Theme.Spacing.s) }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: score)
    }

    private func finish(score s: Int) {
        store.serve(score: s, praise: TemaeJudge.praise(for: s).title)
        Haptics.success()
        score = s
    }
}

/// 結果。点数を数え上げて見せ、ほめ言葉を添える。言葉はほめ言葉だけ(数字で責めない)。
struct ResultView: View {
    let score: Int
    let praise: (title: String, note: String)
    let onClose: () -> Void
    @State private var shown = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            ChawanView(foam: 1, smoothness: 1, size: 150)
            Text(praise.title)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.Palette.text)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(shown)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                Text("集中の目安")
                    .font(.headline)
            }
            .foregroundStyle(Theme.Palette.text)
            Text(praise.note)
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("閉じる") { onClose() }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.s)
        }
        .background(Theme.Palette.background)
        .task {
            // 点数を数え上げる
            for value in stride(from: 0, through: score, by: max(1, score / 30)) {
                withAnimation(.snappy(duration: 0.04)) { shown = value }
                try? await Task.sleep(for: .milliseconds(25))
            }
            withAnimation { shown = score }
            Haptics.impact()
        }
    }
}
