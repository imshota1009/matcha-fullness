import DesignSystem
import SceneKit
import SwiftUI

/// 点てる(本体)。机に置いた iPhone を茶碗に、指を茶筅に見立てる(SPEC 5章 A〜C)。
/// 1. 点てる: 指を縦にまっすぐ往復。往復ごとに振動。泡は採点(泡スコア)に合わせてリアルタイムに変わる
/// 2. 仕上げ: ゆっくり小さく「くるっ」と約300°回して、指を離す
/// 3. 回す: 茶碗を持ち上げ、時計回りに 90° ずつ 2回(合計 180°)まわす(0.5秒止めると1回)。液面は空間に固定して回さない
/// 【変更 10/25】机に置いていなくても点てられる(水平の条件は外した)。茶碗・茶筅は Unity のモデル、液面は LiquidSurface。
struct TemaeView: View {
    let motion: MotionService
    let onFinish: (TemaeResult) -> Void
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @State private var model = TemaeModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            TemaePalette.tatami.ignoresSafeArea()
            // 茶碗は、上のダイナミックアイランドにかからない範囲で最大(左右ははみ出してよい)
            TeaSceneView(model: model)
                .padding(.top, 8)
            // なぞる場所を薄く示す: 点てるときは縦の往復の矢印、仕上げは丸めた矢印
            if model.phase == .whisk || model.phase == .finish {
                TraceGuide(phase: model.phase, center: model.rimCenter, radius: model.rimRadius)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            if model.phase == .rotate || model.phase == .done {
                RotateRing(model: model)
                    .allowsHitTesting(false)
            }
            guide
                .padding(.bottom, Theme.Spacing.s)
        }
        .animation(.easeInOut(duration: 0.4), value: model.phase)
        .onAppear {
            model.start(style: style, motion: motion, onFinish: onFinish)
            // 背景の自然の音(設定でオンのとき)。ししおどしは、点てる時間の中でたまに
            if UserDefaults.standard.bool(forKey: SoundBank.ambientOnKey) { SoundBank.shared.startAmbient(shishiEvery: 75, forTimer: false) }
        }
        .onDisappear {
            model.stop()
            SoundBank.shared.stopAmbient()
        }
    }

    private var guide: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(model.guideText)
                .font(.headline)
                .foregroundStyle(TemaePalette.ink)
                .multilineTextAlignment(.center)
            if model.phase == .whisk {
                Text("泡: \(FoamStage.names[FoamStage.of(Int(model.liveFoam))])  往復 \(model.strokeCount)/\(TemaeConstants.targetStrokes)")
                    .font(.dsCaption.monospacedDigit())
                    .foregroundStyle(TemaePalette.ink.opacity(0.75))
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(TemaePalette.tatami.opacity(0.92), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// 点前の進行と、指・センサーの入力をまとめる
@MainActor
@Observable
final class TemaeModel {
    enum Phase { case whisk, finish, rotate, done }
    private(set) var phase = Phase.whisk
    private(set) var strokeCount = 0
    /// 点てている最中の泡スコア(直近 20 ストローク)
    private(set) var liveFoam = 0.0
    /// 回す: いま回している角度(度、時計回りが正)と、成立した回の角度
    private(set) var turnAngle = 0.0
    private(set) var turns: [Double] = []
    private(set) var counterClockwise = false
    private(set) var finishHint = false
    /// 茶碗の縁(画面上)の中心と半径。目盛りのリングを描くのに使う
    private(set) var rimCenter = CGPoint.zero
    private(set) var rimRadius: CGFloat = 0
    var scene: TeaScene?
    @ObservationIgnored weak var view: SCNView?

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last = CACurrentMediaTime()
    @ObservationIgnored private var motion: MotionService?
    @ObservationIgnored private var onFinish: ((TemaeResult) -> Void)?
    // 指
    @ObservationIgnored private var touchSamples: [Scoring.Sample] = []
    @ObservationIgnored private var touchStrokes = 0
    @ObservationIgnored private var strokes: [Scoring.Stroke] = []
    @ObservationIgnored private var tipWorld: SIMD2<Float>?
    @ObservationIgnored private var chasenPos = SIMD2<Float>(0, 0)
    @ObservationIgnored private var velocity = SIMD2<Float>(0, 0)
    @ObservationIgnored private var lastSign = 0.0
    // 仕上げ・回す
    @ObservationIgnored private var finishScore = 0.0
    @ObservationIgnored private var baseYaw: Double?
    @ObservationIgnored private var gestureAngle = 0.0
    @ObservationIgnored private var holdSince: Double?
    @ObservationIgnored private var holdAngle = 0.0
    @ObservationIgnored private var liquidAtRotateStart: Float = 0
    /// 回す: 点灯している目盛りの本数(1本ふえる・へるごとに触覚)
    @ObservationIgnored private var litTicks = 0
    @ObservationIgnored private let tickFeedback = UISelectionFeedbackGenerator()
    /// 茶筅の手触り(Core Haptics の連続した振動。5章 J)
    @ObservationIgnored private let whiskHaptics = WhiskHaptics()

    var guideText: String {
        switch phase {
        case .whisk: strokeCount == 0 ? "指を茶筅に。奥と手前を、まっすぐ往復" : "まっすぐ、一定のリズムで"
        case .finish: finishHint ? "もう少しゆっくり、くるっと一周してから離します" : "仕上げましょう。ゆっくり小さく、くるっと回して離します"
        case .rotate:
            if counterClockwise { "時計回りに回します ↻" }
            else if turnAngle - (turns.last.map { _ in turns.reduce(0, +) } ?? 0) > TemaeConstants.rotateTarget + TemaeConstants.rotateTolerance { "少し戻しましょう" }
            else { turns.isEmpty ? "茶碗(スマホ)を、時計回りに90°ずつ2回まわしましょう" : "もう1回、時計回りに" }
        case .done: "どうぞ"
        }
    }


    func start(style: ChawanStyle, motion: MotionService, onFinish: @escaping (TemaeResult) -> Void) {
        guard scene == nil else { return }
        let tea = TeaScene(style: style)
        scene = tea
        view?.scene = tea.scene
        view?.pointOfView = tea.camera
        self.motion = motion
        self.onFinish = onFinish
        motion.start()
        whiskHaptics.prepare()
        // 起動引数 `-demoWhisk YES` で、指の代わりに自動で往復させる(画面確認用)
        if UserDefaults.standard.bool(forKey: "demoWhisk") {
            Task { @MainActor [weak self] in
                var t = 0.0
                while let self, self.link != nil, self.phase == .whisk {
                    let size = self.view?.bounds.size ?? CGSize(width: 400, height: 800)
                    self.touchMoved(CGPoint(x: size.width / 2 + sin(t * 0.7) * 6, y: size.height / 2 + sin(t * 8) * size.height * 0.26))
                    t += 1.0 / 60
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
        }
        // 起動引数 `-temaePhase rotate` で「回す」から始める(画面確認用)
        if UserDefaults.standard.string(forKey: "temaePhase") == "rotate" { startRotate() }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        whiskHaptics.stop()
        link?.invalidate()
        link = nil
        motion?.stop()
    }

    // MARK: 指

    /// 指の位置(1つ)。デモの自動往復などから呼ぶ
    func touchMoved(_ p: CGPoint?) {
        guard let p else { touchesMoved([]); return }
        touchesMoved([(p, CACurrentMediaTime())])
    }

    /// 指の位置のまとまり(5章 L-1)。UIKit の coalescedTouches で取った、画面の更新より細かい点(最大 240Hz)を
    /// 時刻つきで受け取り、すべて採点に使う。空なら指が離れた
    func touchesMoved(_ points: [(CGPoint, TimeInterval)]) {
        guard phase == .whisk || phase == .finish else { return }
        guard !points.isEmpty else { endTouch(); return }
        for (p, t) in points {
            guard let w = worldPoint(p) else { continue }
            tipWorld = w
            let q = SIMD2(Double(w.x), Double(w.y)) / Double(TeaScene.liquidRadius)
            touchSamples.append(.init(p: q, t: t))
        }
        guard tipWorld != nil else { return }
        // 新しく往復が1本できたら、振動と、液全体の揺れ
        let n = Scoring.strokes(in: touchSamples).count
        if n > touchStrokes {
            touchStrokes = n
            strokeCount = strokes.count + n
            // 折り返しの瞬間の短いアクセント(茶筅の手触りは Core Haptics。簡易版の「カチッ」は使わない)
            whiskHaptics.accent(fineness: liveFoam / 100)
            SoundBank.shared.chasen()
            scene?.slosh(direction: Float(lastSign))
            updateLiveFoam()
            if phase == .whisk, strokeCount >= TemaeConstants.targetStrokes, liveFoam >= 40 { phase = .finish }
        }
        if touchSamples.count >= 2 {
            let dy = touchSamples[touchSamples.count - 1].p.y - touchSamples[touchSamples.count - 2].p.y
            if dy != 0 { lastSign = dy > 0 ? 1 : -1 }
        }
    }

    private func endTouch() {
        tipWorld = nil
        defer { touchSamples = []; touchStrokes = 0 }
        let ks = Scoring.strokes(in: touchSamples)
        if phase == .finish {
            let m = Scoring.finishMeasure(touchSamples)
            if m.speed <= TemaeConstants.finishFast, m.degrees >= TemaeConstants.finishDegrees {
                // 仕上げ完了。中心に小さなくぼみができ、すぐに戻る
                finishScore = Scoring.finishScore(degrees: m.degrees, speed: m.speed)
                scene?.dimple()
                Haptics.success()
                startRotate()
                return
            }
            if m.speed > TemaeConstants.finishFast { strokes += ks } else if m.degrees > 60 { finishHint = true }
        } else {
            strokes += ks
        }
        strokeCount = strokes.count
        updateLiveFoam()
    }

    private func updateLiveFoam() {
        let all = strokes + Scoring.strokes(in: touchSamples)
        liveFoam = Scoring.foam(all, window: TemaeConstants.liveWindow).foam
    }

    /// 二本指で回す(センサーがないシミュレーターでの代わり)
    func rotate(by radians: Double) { gestureAngle = -radians * 180 / .pi * TemaeConstants.clockwiseSign }

    private func startRotate() {
        phase = .rotate
        tickFeedback.prepare()
        baseYaw = nil
        Haptics.selection()
        // 目盛りのリングが画面に収まるよう、茶碗を少し引いて見せる
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.8
        scene?.camera.position.y = 9.6
        scene?.chasen.opacity = 0  // 茶筅は抜いたので見せない
        SCNTransaction.commit()
    }

    /// 画面の点 → 水面(茶碗の座標)の点
    private func worldPoint(_ p: CGPoint) -> SIMD2<Float>? {
        guard let view else { return nil }
        let a = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 0))
        let b = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 1))
        let t = (TeaScene.liquidY - a.y) / (b.y - a.y)
        var q = SIMD2(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t)
        let maxR = TeaScene.liquidRadius - 0.06
        if simd_length(q) > maxR { q = simd_normalize(q) * maxR }
        return q
    }

    // MARK: 毎フレーム

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = Float(min(0.05, now - last))
        last = now
        guard let scene else { return }

        // 茶筅は指を少し遅れて追い、動く方向に少し傾く
        let target = tipWorld ?? chasenPos
        let prev = chasenPos
        chasenPos += (target - chasenPos) * min(1, dt * 22)
        velocity = velocity * 0.7 + ((chasenPos - prev) / max(dt, 0.001)) * 0.3
        let touching = tipWorld != nil
        let node = scene.chasen
        let y: Float = phase == .rotate || phase == .done ? 3.2 : (touching ? TeaScene.liquidY - 0.03 : TeaScene.liquidY + 0.25)
        node.position.x = chasenPos.x
        node.position.z = chasenPos.y
        node.position.y += (y - node.position.y) * min(1, dt * (phase == .rotate ? 4 : 14))
        let tilt = simd_clamp(velocity * 0.12, SIMD2(-0.45, -0.45), SIMD2(0.45, 0.45))
        node.eulerAngles.z += (-tilt.x - node.eulerAngles.z) * min(1, dt * 12)
        node.eulerAngles.x += (tilt.y - node.eulerAngles.x) * min(1, dt * 12)

        // 液面(持ち上げられているときも、揺れと泡がはじける動きは続ける)
        scene.step(dt: dt, input: .init(tip: touching ? chasenPos : nil, velocity: velocity,
                                        whisking: touching && phase == .whisk || (touching && phase == .finish && simd_length(velocity) > 1.6),
                                        smoothing: touching && phase == .finish, foamScore: liveFoam))

        // 指が触れている間は、速さと泡の細かさに合わせて連続した振動
        whiskHaptics.update(touching: touching && (phase == .whisk || phase == .finish),
                            speed: Double(simd_length(velocity)), fineness: liveFoam / 100)
        if phase == .rotate { updateRotate(now: now) }
        updateRim()
    }

    // MARK: 回す

    private func updateRotate(now: Double) {
        guard let motion, let scene else { return }
        let angle: Double
        if motion.isAvailable {
            // 回す手順に入ったときの向きを 0 にする(持ち上げなくても回せる)
            if baseYaw == nil { baseYaw = motion.yaw }
            angle = (motion.yaw - (baseYaw ?? 0)) * 180 / .pi * TemaeConstants.clockwiseSign
            // 液面は回さない: iPhone が回った分だけ、逆向きに回して打ち消す
            scene.setLiquidRotation(Float(-(motion.yaw - (baseYaw ?? 0))))
        } else {
            angle = gestureAngle
        }
        turnAngle = angle
        counterClockwise = angle < -5
        // 目盛り(2° ごと)が1本動くたびに、Face ID の登録のような軽い触覚
        let ticks = Int(max(0, min(angle, TemaeConstants.rotateTarget * Double(TemaeConstants.rotateTimes))) / 2)
        if ticks != litTicks {
            litTicks = ticks
            if UserDefaults.standard.object(forKey: Haptics.storageKey) as? Bool ?? true { tickFeedback.selectionChanged() }
            tickFeedback.prepare()
        }
        // いまの回の角度(2回目は、1回目で止めた位置から測る)
        let done = turns.reduce(0, +)
        let current = angle - done
        if abs(angle - holdAngle) > 1.5 { holdSince = now; holdAngle = angle }
        if let since = holdSince, now - since >= TemaeConstants.rotateHold,
           abs(current - TemaeConstants.rotateTarget) <= TemaeConstants.rotateTolerance {
            turns.append(current)
            holdSince = nil
            Haptics.impact()  // カチッ
            if turns.count >= TemaeConstants.rotateTimes { complete() }
        }
    }

    private func complete() {
        phase = .done
        Haptics.success()
        let all = Scoring.foam(strokes)
        let rotate = Scoring.rotateScore(turns)
        let result = TemaeResult(score: Scoring.total(foam: all.foam, finish: finishScore, rotate: rotate),
                                 foam: Int(all.foam.rounded()), line: Int(all.line.rounded()), rhythm: Int(all.rhythm.rounded()),
                                 count: Int(all.count.rounded()), finish: Int(finishScore.rounded()), rotate: Int(rotate.rounded()))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))  // 目盛りが一度だけ点灯して消えるのを見せる
            self?.onFinish?(result)
        }
    }

    private func updateRim() {
        guard let view, view.bounds.width > 0 else { return }
        let c = view.projectPoint(SCNVector3(0, 0.84, 0))
        let e = view.projectPoint(SCNVector3(1.0, 0.84, 0))
        let center = CGPoint(x: CGFloat(c.x), y: CGFloat(c.y) + view.frame.minY)
        let r = CGFloat(abs(e.x - c.x))
        if abs(center.x - rimCenter.x) > 0.5 || abs(r - rimRadius) > 0.5 { rimCenter = center; rimRadius = r }
    }
}

/// なぞる場所を薄く示す案内。点てるときは茶碗の奥から手前までの縦の往復矢印(⇕)、
/// 仕上げは中央の小さな丸めた矢印(くるっと一周)。白く、ごく薄く表示して、泡の見た目をじゃましない。
struct TraceGuide: View {
    let phase: TemaeModel.Phase
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            guard radius > 20 else { return }
            let r = radius * 0.62
            let ink = GraphicsContext.Shading.color(.white.opacity(0.32))
            let style = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
            if phase == .whisk {
                let top = CGPoint(x: center.x, y: center.y - r), bottom = CGPoint(x: center.x, y: center.y + r)
                var p = Path()
                p.move(to: top); p.addLine(to: bottom)
                for (tip, d) in [(top, 1.0), (bottom, -1.0)] {
                    p.move(to: CGPoint(x: tip.x - 18, y: tip.y + 18 * d)); p.addLine(to: tip); p.addLine(to: CGPoint(x: tip.x + 18, y: tip.y + 18 * d))
                }
                ctx.stroke(p, with: ink, style: style)
            } else {
                let rr = radius * 0.28
                var p = Path()
                p.addArc(center: center, radius: rr, startAngle: .degrees(-90), endAngle: .degrees(210), clockwise: false)
                ctx.stroke(p, with: ink, style: style)
                // 矢じり(進む向き)
                let end = Angle.degrees(210).radians
                let tip = CGPoint(x: center.x + cos(end) * rr, y: center.y + sin(end) * rr)
                let dir = CGPoint(x: -sin(end), y: cos(end))
                let back = CGPoint(x: tip.x - dir.x * 18, y: tip.y - dir.y * 18)
                let side = CGPoint(x: -dir.y * 12, y: dir.x * 12)
                var head = Path()
                head.move(to: CGPoint(x: back.x + side.x, y: back.y + side.y)); head.addLine(to: tip); head.addLine(to: CGPoint(x: back.x - side.x, y: back.y - side.y))
                ctx.stroke(head, with: ink, style: style)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(phase == .whisk ? "奥と手前を、まっすぐ往復します" : "中央で、くるっと一周します")
    }
}

/// 回した量がひと目でわかる目盛りのリング(SPEC 5章 C。Face ID の登録画面のような進捗リング)。
/// 茶碗の縁の外側に 2° ごとの短い目盛り。回す範囲(0〜180°)だけ薄い墨で出し、回した角度まで抹茶色に点灯する。
/// 回しすぎた分は朱。茶碗の手前(下)に「正面」の印。
struct RotateRing: View {
    let model: TemaeModel
    @State private var flash = false

    var body: some View {
        Canvas { ctx, _ in
            let c = model.rimCenter, r = model.rimRadius + 10
            guard r > 20 else { return }
            let done = model.turns.reduce(0, +)
            let upper = done + TemaeConstants.rotateTarget + TemaeConstants.rotateTolerance
            // 開始位置は手前(画面の下)。時計回り = 画面上でも時計回り
            let total = TemaeConstants.rotateTarget * Double(TemaeConstants.rotateTimes)
            for k in 0...Int(total / 2) {
                let deg = Double(k) * 2
                let a = (90 + deg) * .pi / 180
                let inner = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                let outer = CGPoint(x: c.x + cos(a) * (r + 14), y: c.y + sin(a) * (r + 14))
                var p = Path(); p.move(to: inner); p.addLine(to: outer)
                let lit = deg <= model.turnAngle
                let confirmed = deg <= done
                let over = lit && deg > upper
                let color: Color = over ? Theme.Palette.vermilion : lit ? Theme.Palette.matcha : TemaePalette.ink.opacity(0.25)
                ctx.stroke(p, with: .color(flash ? Theme.Palette.matcha : color), lineWidth: confirmed ? 3.5 : 2)
            }
            // 「1/2」「2/2」
            for (j, label) in ["1/2", "2/2"].enumerated() where model.turns.count > j {
                let a = (90 + Double(j + 1) * TemaeConstants.rotateTarget + 6) * .pi / 180
                ctx.draw(Text(label).font(.caption.weight(.semibold)).foregroundStyle(TemaePalette.ink),
                         at: CGPoint(x: c.x + cos(a) * (r + 30), y: c.y + sin(a) * (r + 30)))
            }
            // 正面の印(茶碗の縁の手前)
            let front = CGPoint(x: c.x, y: c.y + model.rimRadius - 6)
            ctx.fill(Path(ellipseIn: CGRect(x: front.x - 6, y: front.y - 6, width: 12, height: 12)), with: .color(TemaePalette.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: front.x - 3, y: front.y - 3, width: 6, height: 6)), with: .color(Theme.Palette.vermilion))
        }
        .opacity(model.phase == .done && flash ? 0 : 1)
        .onChange(of: model.phase) { _, p in
            guard p == .done else { return }
            withAnimation(.easeIn(duration: 0.3)) { flash = true }
        }
        .accessibilityElement()
        .accessibilityLabel("回した角度 \(Int(model.turnAngle))度。\(model.turns.count)回目まで成立")
    }
}

/// SceneKit の画面。指の動きをモデルへ渡す(SwiftUI のジェスチャーより遅れが少ない)
struct TeaSceneView: UIViewRepresentable {
    let model: TemaeModel

    func makeUIView(context: Context) -> TouchSCNView {
        let v = TouchSCNView()
        v.scene = model.scene?.scene
        v.pointOfView = model.scene?.camera
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.preferredFramesPerSecond = 60
        v.model = model
        model.view = v
        let rot = UIRotationGestureRecognizer(target: v, action: #selector(TouchSCNView.rotated(_:)))
        v.addGestureRecognizer(rot)
        v.isAccessibilityElement = true
        v.accessibilityLabel = "茶碗。指を茶筅にして点てます"
        return v
    }

    func updateUIView(_ v: TouchSCNView, context: Context) {
        if v.scene == nil, let s = model.scene {
            v.scene = s.scene
            v.pointOfView = s.camera
        }
    }
}

/// 指の軌跡を UIKit で受け取る(5章 L-1)。SwiftUI のジェスチャーでは取れない「間の点」(coalescedTouches)まで取り、
/// 画面の更新(60〜120Hz)より細かい最大 240Hz の点で採点する。時刻はタッチの時刻(timestamp)を使う
final class TouchSCNView: SCNView {
    weak var model: TemaeModel?
    private func points(_ t: Set<UITouch>, _ e: UIEvent?) -> [(CGPoint, TimeInterval)] {
        guard let touch = t.first else { return [] }
        let all = e?.coalescedTouches(for: touch) ?? [touch]
        return all.map { ($0.location(in: self), $0.timestamp) }
    }
    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchesMoved(points(t, e)) }
    override func touchesMoved(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchesMoved(points(t, e)) }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchesMoved([]) }
    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchesMoved([]) }
    @objc func rotated(_ g: UIRotationGestureRecognizer) { model?.rotate(by: Double(g.rotation)) }
}

/// 点前の色。背景は畳をイメージした単色(アイコンと同じカーキ)。ほかは4色の範囲
enum TemaePalette {
    static let tatami = Color(red: 0.65, green: 0.62, blue: 0.50)  // アプリアイコンの背景と同じ
    static let ink = Theme.Palette.kogecha
    static let matcha = Theme.Palette.matcha
    static let foam = Color(red: 0.70, green: 0.78, blue: 0.52)
}

/// Unity で作った茶碗の寸法(app/unity/chawan.json と同じ値)
enum ChawanSpec {
    static let liquid: CGFloat = 0.80
    static let imageExtent: CGFloat = 1.02
}
