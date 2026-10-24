import DesignSystem
import SwiftUI

/// 一服(F2〜F5)。点てる約15秒 → 整える約5秒 → 点前の評価 → 呼吸30秒 → 今日の一事 → 掛け軸 → 石臼へ。
/// 振るのが基本。振れないとき(シミュレーター・手がふさがっているとき)は茶碗を押しても点てられる(代替経路)。
struct IppukuView: View {
    @Environment(TeaStore.self) private var store
    let motion: MotionService
    let go: (Stage) -> Void

    enum Step { case whisk, settle, praise, breath, ichiji, kakejiku }
    @State private var step = Step.whisk
    @State private var whisks: [Date] = []
    @State private var startedAt: Date?
    @State private var settleStart: Date?
    @State private var praise = TemaeJudge.praise(for: 0.7)
    @State private var ichiji = ""
    @FocusState private var focused: Bool

    private let whiskSeconds = 15.0
    private let settleSeconds = 5.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackToEntrance(go: go)
                Spacer()
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Color.clear.frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .padding(.horizontal, Theme.Spacing.s)

            Group {
                switch step {
                case .whisk, .settle: whiskView
                case .praise: praiseView
                case .breath: BreathView { step = .ichiji; focused = true }
                case .ichiji: ichijiView
                case .kakejiku: kakejikuView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .onAppear { motion.start(onWhisk: { whisk(at: $0) }) }
        .onDisappear { motion.setWhiskHandler(nil) }
    }

    private var title: String {
        switch step {
        case .whisk: "一服を点てる"
        case .settle: "整える"
        case .praise: "お点前"
        case .breath: "ひと息"
        case .ichiji, .kakejiku: "今日の一事"
        }
    }

    // MARK: - 点てる・整える

    private var whiskView: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
            let settleElapsed = settleStart.map { context.date.timeIntervalSince($0) } ?? 0
            VStack(spacing: Theme.Spacing.l) {
                Spacer()
                Text(store.record.matchaCups > 0 ? "自分で挽いた抹茶で、点てましょう" : "おもてなしの一杯を、点てましょう")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Button { whisk(at: .now) } label: {
                    ChawanView(foam: min(1, Double(whisks.count) / 40), smoothness: step == .settle ? min(1, settleElapsed / settleSeconds) : 0)
                }
                .buttonStyle(.plain)
                .disabled(step == .settle)
                .accessibilityLabel("茶碗。押すと点てられます")
                Text(step == .settle ? "ゆっくり、泡を整えています" : (whisks.isEmpty ? "スマホを小さく前後に振ってください" : "シャカ、シャカ。その調子です"))
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.text)
                // 残り時間は数字ではなく細い線で見せる
                Capsule()
                    .fill(Theme.Palette.separator)
                    .frame(width: 200, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.Palette.matcha)
                            .frame(width: 200 * (step == .settle ? 1 : min(1, elapsed / whiskSeconds)), height: 4)
                    }
                Text(motion.isAvailable ? "強く振らなくても点てられます。ストラップの使用をおすすめします" : "茶碗を押しても点てられます")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
            }
            .onChange(of: context.date) { _, now in tick(now: now) }
        }
    }

    private func whisk(at date: Date) {
        guard step == .whisk else { return }
        if startedAt == nil { startedAt = date }
        whisks.append(date)
        SoundBank.shared.chasen()
        Haptics.selection()
    }

    private func tick(now: Date) {
        if step == .whisk, let startedAt, now.timeIntervalSince(startedAt) >= whiskSeconds {
            step = .settle
            settleStart = now
            praise = TemaeJudge.praise(for: TemaeJudge.steadiness(whisks))
        } else if step == .settle, let settleStart, now.timeIntervalSince(settleStart) >= settleSeconds {
            Haptics.success()
            step = .praise
        }
    }

    // MARK: - 評価

    private var praiseView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            ChawanView(foam: 1, smoothness: 1, size: 200)
            Text(praise.title)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.Palette.text)
            Text(praise.note)
                .font(.dsBody)
                .foregroundStyle(Theme.Palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("ひと息つく") { step = .breath }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.s)
        }
    }

    // MARK: - 今日の一事

    private var ichijiView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Spacer()
            Text("このあと、ひとつだけ。")
                .font(.dsTitle)
                .foregroundStyle(Theme.Palette.text)
            Text("次にやることを一言で書くと、掛け軸になります。")
                .font(.dsBody)
                .foregroundStyle(Theme.Palette.secondaryText)
            TextField("例: 英単語を三十", text: $ichiji)
                .font(.title3)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(hang)
                .frame(minHeight: Theme.Size.primaryButton)
                .padding(.horizontal, Theme.Spacing.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
            Spacer()
            PrimaryButton("掛け軸にする") { hang() }
                .disabled(ichiji.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(ichiji.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .padding(.bottom, Theme.Spacing.s)
        }
        .padding(.horizontal, Theme.Spacing.screen)
    }

    private func hang() {
        let text = ichiji.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        focused = false
        store.serve(praise: praise.title, ichiji: text)
        Haptics.success()
        step = .kakejiku
    }

    private var kakejikuView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            KakejikuView(text: ichiji.trimmingCharacters(in: .whitespaces), height: 340)
                .transition(.move(edge: .top).combined(with: .opacity))
            Text("スマホを伏せると、石臼が回りはじめます")
                .font(.dsBody)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            PrimaryButton("石臼へ", systemImage: "circle.dotted") { go(.ishiusu) }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.s)
        }
        .task {
            // 一事を決めたら自動で集中へ(F6)
            try? await Task.sleep(for: .seconds(3))
            if step == .kakejiku { go(.ishiusu) }
        }
    }
}

/// F4 呼吸の案内。松風が強まる5秒で吸い、静まる5秒で吐く。3回で約30秒。音が出せなくても振動で区切りを伝える。
struct BreathView: View {
    let onFinish: () -> Void
    @State private var start = Date()
    private let cycle = 10.0
    private let rounds = 3

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let inCycle = t.truncatingRemainder(dividingBy: cycle)
            let inhaling = inCycle < cycle / 2
            let level = inhaling ? inCycle / (cycle / 2) : 1 - (inCycle - cycle / 2) / (cycle / 2)
            let round = min(rounds, Int(t / cycle) + 1)
            VStack(spacing: Theme.Spacing.l) {
                Spacer()
                ZStack {
                    Circle().stroke(Theme.Palette.separator, lineWidth: 2).frame(width: 240, height: 240)
                    Circle().fill(Theme.Palette.matcha.opacity(0.85))
                        .frame(width: 90 + 150 * level, height: 90 + 150 * level)
                }
                .frame(height: 260)
                Text(inhaling ? "吸って" : "吐いて")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                Text("釜の音が強まったら吸い、静まったら吐く(\(round) / \(rounds))")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
            }
            .onChange(of: inhaling) { _, _ in Haptics.selection() }
            .onChange(of: level) { _, newValue in SoundBank.shared.setMatsukaze(newValue) }
            .onChange(of: t >= cycle * Double(rounds)) { _, done in if done { onFinish() } }
        }
        .onAppear {
            start = .now
            SoundBank.shared.startMatsukaze()
        }
        .onDisappear { SoundBank.shared.stopMatsukaze() }
        .accessibilityElement(children: .combine)
    }
}
