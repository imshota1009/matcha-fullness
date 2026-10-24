import DesignSystem
import SwiftUI

/// 柿1つの画面。熟していれば「買う / 見送る」を決め、食べごろの前なら残り時間を見せる。
/// どちらを選んでも判子が押され、少し待ってから閉じる。食べごろの前でも「降ろす」で消せる(ホームで元に戻せる)。
struct DecideSheet: View {
    @Environment(KakiStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let kaki: Kaki
    @State private var stampText: String?
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let ripe = kaki.isRipe(at: context.date)
                DSScreen(ripe ? "食べごろです" : "干している途中") {
                    VStack(spacing: Theme.Spacing.m) {
                        ZStack {
                            DryView(kind: kaki.kind, ripeness: kaki.ripeness(at: context.date), size: 140, showsString: true)
                            if let stampText {
                                Stamp(stampText, isStamped: true, size: 96)
                                    .offset(x: 70, y: 40)
                                    .transition(.scale(scale: 1.6).combined(with: .opacity))
                            }
                        }
                        .frame(height: 210)
                        Text(kaki.name)
                            .font(.dsTitle)
                            .foregroundStyle(Theme.Palette.text)
                        Text(kaki.price.yen)
                            .font(.dsBody.monospacedDigit())
                            .foregroundStyle(Theme.Palette.secondaryText)
                        Text(ripe ? "干して、待った。\nそれでも、まだ欲しいですか?" : "食べごろまで \(RemainingText.make(until: kaki.ripeAt, now: context.date))。\nいまは買わずに、待ちましょう。")
                            .font(.dsBody)
                            .foregroundStyle(Theme.Palette.text)
                            .multilineTextAlignment(.center)
                            .padding(.top, Theme.Spacing.s)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.l)
                } bottom: {
                    if ripe {
                        decisionButtons
                    } else {
                        Button(role: .destructive) { confirmRemove = true } label: {
                            Label("軒下から降ろす", systemImage: "scissors")
                                .font(.dsBody)
                                .foregroundStyle(Theme.Palette.vermilion)
                                .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
            .confirmationDialog("「\(kaki.name)」を降ろしますか?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("降ろす", role: .destructive) {
                    Haptics.warning()
                    store.remove(kaki)
                    dismiss()
                }
            } message: {
                Text("降ろしたあと、ホームで元に戻せます。")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// 見送るを主(黒)、買うを副(枠線)にする。アプリの目的は「待って選ぶ」ことなので、見送りをすすめる
    private var decisionButtons: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button { decide(.bought) } label: {
                Text("買う")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                    .foregroundStyle(Theme.Palette.text)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.l).strokeBorder(Theme.Palette.text, lineWidth: 1.5))
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleStyle())
            PrimaryButton("見送る") { decide(.passed) }
        }
        .disabled(stampText != nil)
    }

    private func decide(_ decision: Kaki.Decision) {
        withAnimation(.spring(duration: 0.3, bounce: 0.35)) {
            stampText = decision == .passed ? "見送" : "購入"
        }
        Haptics.impact()
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            store.decide(kaki, decision)
            dismiss()
        }
    }
}
