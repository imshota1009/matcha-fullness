import Combine
import DesignSystem
import SwiftUI

/// F6 石臼の集中タイマー / F7 次の一服。
/// スマホを伏せている間だけ石臼が回り、抹茶が挽けていく。手に取ると止まるだけで、挽いた分は消えない。
/// シミュレーターなどセンサーがないときは、伏せているものとして回す。
struct IshiusuScreen: View {
    @Environment(TeaStore.self) private var store
    let motion: MotionService
    let go: (Stage) -> Void

    @State private var angle = 0.0
    @State private var finished = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var grinding: Bool { !finished && (motion.isFaceDown || !motion.isAvailable) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackToEntrance(go: go)
                Spacer()
                Text(finished ? "ひき終わりました" : "石うす")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Color.clear.frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .padding(.horizontal, Theme.Spacing.s)

            Spacer()
            if let ichiji = store.record.latestIchiji {
                Text("「\(ichiji)」")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.Palette.text)
                    .padding(.bottom, Theme.Spacing.l)
            }
            IshiusuView(angle: angle, powder: finished ? 1 : store.record.grindProgress, size: 240)
            Text(message)
                .font(.dsBody)
                .foregroundStyle(Theme.Palette.text)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.l)
                .padding(.horizontal, Theme.Spacing.xl)
            Text(store.isFastMode ? "早送り中(集中25分を10秒に)" : "集中は25分です")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .padding(.top, Theme.Spacing.s)
            Spacer()

            if finished {
                PrimaryButton("ひいた抹茶で、次の一杯をたてる", systemImage: "cup.and.saucer") { go(.ippuku) }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.s)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: finished)
        .onAppear {
            motion.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(timer) { _ in
            guard grinding else { return }
            angle += 6
            if store.grind(seconds: 0.1) {
                finished = true
                SoundBank.shared.suikinkutsu()
                Haptics.success()
            }
        }
        .onChange(of: motion.isFaceDown) { _, down in if !finished { Haptics.selection(); _ = down } }
    }

    private var message: String {
        if finished { return "抹茶が一杯ぶんひけました。\nひと休みしましょう。" }
        if grinding { return "石うすが回っています。\nこのまま、やることに向かいましょう。" }
        return "スマホをうら返すと、石うすが回ります。\n手に取っている間は止まるだけ。ひいた分は残ります。"
    }
}
