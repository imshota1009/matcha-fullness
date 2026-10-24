import DesignSystem
import SwiftUI

/// 一服(F2〜F5)。点てる約15秒 → 整える約5秒 → 点前の結果(点数・茶点・段位) → 呼吸30秒 → 今日の一事 → 掛け軸 → 石臼へ。
/// 点て方は2つ(設定で切り替え):
/// - 振って点てる: スマホを手に持ち、振る・回す
/// - 指で点てる: スマホを机に置き、上から見た茶碗の上で指を前後に動かす
/// どちらのときも、茶碗を押せば点てられる(代替経路)。
struct IppukuView: View {
    @Environment(TeaStore.self) private var store
    @AppStorage(WhiskMode.storageKey) private var mode = WhiskMode.gyro
    let motion: MotionService
    let go: (Stage) -> Void

    enum Step { case whisk, settle, result, breath, ichiji, kakejiku }
    @State private var step = Step.whisk
    @State private var whisks: [Date] = []
    @State private var startedAt: Date?
    @State private var settleStart: Date?
    @State private var result: TeaStore.Result?
    @State private var praise = TemaeJudge.praise(for: 75)
    @State private var visitedCells: Set<Int> = []
    @State private var ichiji = ""
    @FocusState private var focused: Bool

    private let whiskSeconds = 15.0
    private let settleSeconds = 5.0

    var body: some View {
        if mode == .finger && step == .whisk {
            // 指で点てる: 画面いっぱいの茶碗(真上から)。左上の x でいつでも抜けられる
            TemaeView(motion: motion) { score in finishTemae(score: score) }
                .overlay(alignment: .topLeading) { BackToEntrance(go: go).padding(.leading, Theme.Spacing.s) }
                .transition(.opacity)
        } else {
            flow
        }
    }

    private var flow: some View {
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
                case .result: if let result { ResultView(result: result, praise: praise, total: store.record.totalPoints) { step = .breath } }
                case .breath: BreathView { step = .ichiji; focused = true }
                case .ichiji: ichijiView
                case .kakejiku: kakejikuView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .onAppear {
            motion.start(onWhisk: { date in if mode == .gyro { whisk(at: date) } })
        }
        .onDisappear { motion.setWhiskHandler(nil) }
        // 起動引数 `-ippukuStep kakejiku` で掛け軸から始める(画面確認用)
        .task {
            if UserDefaults.standard.string(forKey: "ippukuStep") == "kakejiku" {
                ichiji = "英単語を三十"
                step = .kakejiku
            }
        }
    }

    private var title: String {
        switch step {
        case .whisk: mode.title
        case .settle: "整える"
        case .result: "お点前"
        case .breath: "ひと息"
        case .ichiji, .kakejiku: "今日の一事"
        }
    }

    // MARK: - 点てる・整える

    private var whiskView: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = startedAt.map { context.date.timeIntervalSince($0) } ?? 0
            let settleElapsed = settleStart.map { context.date.timeIntervalSince($0) } ?? 0
            let foam = min(1, Double(whisks.count) / 40)
            let smooth = step == .settle ? min(1, settleElapsed / settleSeconds) : 0
            VStack(spacing: Theme.Spacing.l) {
                Spacer(minLength: 0)
                Text(store.record.matchaCups > 0 ? "自分で挽いた抹茶で、点てましょう" : "おもてなしの一杯を、点てましょう")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)

                if mode == .finger {
                    FingerWhiskPad(foam: foam, smoothness: smooth, enabled: step == .whisk,
                                   onStroke: { whisk(at: .now) },
                                   onVisit: { visitedCells.insert($0) })
                } else {
                    Button { whisk(at: .now) } label: {
                        ChawanView(foam: foam, smoothness: smooth)
                    }
                    .buttonStyle(.plain)
                    .disabled(step == .settle)
                    .accessibilityLabel("茶碗。押しても点てられます")
                }

                Text(guide)
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.text)
                    .multilineTextAlignment(.center)
                // 残り時間は数字ではなく細い線で見せる
                Capsule()
                    .fill(Theme.Palette.separator)
                    .frame(width: 200, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.Palette.matcha)
                            .frame(width: 200 * (step == .settle ? 1 : min(1, elapsed / whiskSeconds)), height: 4)
                    }
                Text(hint)
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer(minLength: 0)
            }
            .onChange(of: context.date) { _, now in tick(now: now) }
        }
    }

    private var guide: String {
        if step == .settle { return "ゆっくり、泡を整えています" }
        if whisks.isEmpty { return mode == .finger ? "茶碗の上で、指を前後に動かしてください" : "スマホを小さく振るか、手首を回してください" }
        return "シャカ、シャカ。その調子です"
    }

    private var hint: String {
        switch mode {
        case .finger: "スマホは机に置いたまま。茶碗の端から端まで動かすと、泡がそろいます"
        case .gyro: motion.isAvailable ? "強く振らなくても点てられます。ストラップの使用をおすすめします" : "茶碗を押しても点てられます"
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
        } else if step == .settle, let settleStart, now.timeIntervalSince(settleStart) >= settleSeconds {
            finishWhisking()
        }
    }

    private func finishTemae(score: Int) {
        praise = TemaeJudge.praise(for: score)
        result = store.serve(score: score, praise: praise.title, mode: .finger)
        Haptics.success()
        withAnimation { step = .result }
    }

    private func finishWhisking() {
        let start = startedAt ?? .now
        let coverage = mode == .finger ? Double(visitedCells.count) / Double(FingerWhiskPad.cellCount) : nil
        let score = TemaeJudge.score(times: whisks, start: start, seconds: whiskSeconds, coverage: coverage)
        praise = TemaeJudge.praise(for: score)
        result = store.serve(score: score, praise: praise.title, mode: mode)
        Haptics.success()
        step = .result
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
        store.setIchiji(text)
        Haptics.success()
        step = .kakejiku
    }

    private var kakejikuView: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            KakejikuView(text: ichiji.trimmingCharacters(in: .whitespaces), height: 340, unrolls: true)
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
            try? await Task.sleep(for: .seconds(1.0 + Double(ichiji.count) * 0.55 + 2.0))
            if step == .kakejiku { go(.ishiusu) }
        }
    }
}

/// 指で点てる茶碗(上から見た目線)。指の位置に茶筅の先を描き、前後に動かして向きが変わるたびに1回点てる。
/// 茶碗のどこをなぞったか(マス目)も記録し、全体に行き渡ったかを採点に使う。
struct FingerWhiskPad: View {
    var foam: Double
    var smoothness: Double
    var enabled: Bool
    var onStroke: () -> Void
    var onVisit: (Int) -> Void

    static let grid = 4
    static var cellCount: Int { grid * grid }

    @State private var tip: CGPoint?
    @State private var lastPoint: CGPoint?
    @State private var direction = 0.0
    @State private var travel = 0.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ChawanView(foam: foam, smoothness: smoothness, size: size)
                if let tip { Image("ChasenTop").resizable().frame(width: size * 0.32, height: size * 0.32).position(tip).allowsHitTesting(false) }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        tip = value.location
                        track(value.location, size: size)
                    }
                    .onEnded { _ in
                        tip = nil
                        lastPoint = nil
                        travel = 0
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 320)
        .padding(.horizontal, Theme.Spacing.l)
        .accessibilityLabel("茶碗。指を前後に動かして点てます")
    }

    private func track(_ p: CGPoint, size: CGFloat) {
        // マス目に記録(茶碗のどこまで行き渡ったか)
        let col = min(Self.grid - 1, max(0, Int(p.x / size * CGFloat(Self.grid))))
        let row = min(Self.grid - 1, max(0, Int(p.y / size * CGFloat(Self.grid))))
        onVisit(row * Self.grid + col)

        defer { lastPoint = p }
        guard let last = lastPoint else { return }
        // 主に動いている向き(縦か横)の変化を見る。12pt 以上動いてから向きが変わったら1回
        let dx = p.x - last.x, dy = p.y - last.y
        let delta = abs(dy) >= abs(dx) ? dy : dx
        guard abs(delta) > 0.5 else { return }
        let sign: Double = delta > 0 ? 1 : -1
        if sign != direction {
            if travel > 12 { onStroke() }
            direction = sign
            travel = 0
        }
        travel += abs(delta)
    }
}

/// 茶筅の先(上から見た形)。細い線を放射状に並べる
struct ChasenTip: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.shiro.opacity(0.9), lineWidth: 2)
            ForEach(0..<16) { i in
                Rectangle()
                    .fill(Theme.Palette.shiro.opacity(0.85))
                    .frame(width: 1.2, height: size * 0.42)
                    .offset(y: -size * 0.21)
                    .rotationEffect(.degrees(Double(i) * 22.5))
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

/// 点前の結果。点数を数え上げて見せ、茶点・自己ベスト・段位の進み具合を出す。言葉は褒め言葉だけ。
/// Mobbin の LinkedIn ゲーム(Wend)の結果画面を参考に、「また明日」で終える。
struct ResultView: View {
    let result: TeaStore.Result
    let praise: (title: String, note: String)
    let total: Int
    let onNext: () -> Void
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
                Text("集中度")
                    .font(.headline)
            }
            .foregroundStyle(Theme.Palette.text)
            Text(praise.note)
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.s) {
                Label("+\(result.points) 茶点", systemImage: "leaf")
                if result.isBest { Label("自己ベスト", systemImage: "crown") }
            }
            .font(.dsCaption.weight(.semibold))
            .foregroundStyle(Theme.Palette.matcha)
            .padding(.top, Theme.Spacing.s)

            RankProgress(total: total, promoted: result.rankAfter.name != result.rankBefore.name)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
            Spacer()
            PrimaryButton("ひと息つく") { onNext() }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.s)
        }
        .task {
            // 点数を数え上げる
            for value in stride(from: 0, through: result.score, by: max(1, result.score / 30)) {
                withAnimation(.snappy(duration: 0.04)) { shown = value }
                try? await Task.sleep(for: .milliseconds(25))
            }
            withAnimation { shown = result.score }
            Haptics.impact()
        }
    }
}

/// 段位と、次の段位までの進み具合
struct RankProgress: View {
    let total: Int
    var promoted = false

    var body: some View {
        let rank = Rank.current(for: total)
        let next = Rank.next(for: total)
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(promoted ? "昇段 \(rank.name)" : "段位 \(rank.name)")
                    .font(.dsCaption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Text(next.map { "次の\($0.name)まで \($0.threshold - total)" } ?? "皆伝です")
                    .font(.dsCaption.monospacedDigit())
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.separator)
                    Capsule().fill(Theme.Palette.matcha).frame(width: geo.size.width * Rank.progress(for: total))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
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
