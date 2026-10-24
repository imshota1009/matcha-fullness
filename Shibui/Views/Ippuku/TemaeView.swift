import DesignSystem
import SceneKit
import SwiftUI

/// 点前(指で点てる)。スマホを机に置き、画面を茶碗の水面に見立てて、指を茶筅として点てる。
/// 実際の薄茶の点て方に沿った流れ:
/// 1. 点てる: 手首を使って、すばやく前後に(M の字)。粉のダマがほぐれ、泡が立つ(約12秒)
/// 2. 整える: 茶筅を浮かせて表面をなでる。大きな泡がつぶれ、きめが細かくなる
/// 3. 「の」の字: 泡を中央に集め、茶筅を抜く
/// 4. 回す: 茶碗(iPhone)を机の上で回してお出しする。センサーで感知して終わる
/// 茶碗・茶筅は Unity で作った 3D モデル、抹茶は波と泡の計算で動く 3D の水面(TeaScene)。
/// うまさは「集中度」(0〜100)として返す。直線の往復からどれだけ外れたか(離脱率)が中心。
struct TemaeView: View {
    let motion: MotionService
    /// true: スマホを振ってたてる(茶せんが振りに合わせて動く)。整える・の字・回すは指とセンサーで同じ
    var gyro = false
    let onFinish: (_ score: Int) -> Void
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @State private var model = TemaeModel()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TemaePalette.tatami.ignoresSafeArea()
                // 茶碗は、上のダイナミックアイランドにかからない範囲で最大(左右ははみ出してよい)
                TeaSceneView(model: model)
                    .padding(.top, 8)
                guide
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        .onAppear {
            model.start(style: style, motion: motion, gyro: gyro, onFinish: onFinish)
        }
        .onDisappear { model.stop() }
    }

    private var guide: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(model.guideText)
                .font(.headline)
                .foregroundStyle(TemaePalette.ink)
                .multilineTextAlignment(.center)
            Capsule().fill(TemaePalette.ink.opacity(0.2)).frame(width: 160, height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(TemaePalette.ink).frame(width: 160 * model.progress, height: 4)
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
    enum Phase { case whisk, smooth, no, lift, turn, done }
    private(set) var phase = Phase.whisk
    private(set) var progress = 0.0
    var scene: TeaScene?
    @ObservationIgnored weak var view: SCNView?

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last = CACurrentMediaTime()
    @ObservationIgnored private var touch: CGPoint?
    @ObservationIgnored private var tipWorld: SIMD2<Float>?
    @ObservationIgnored private var chasenPos = SIMD2<Float>(0, 0)
    @ObservationIgnored private var velocity = SIMD2<Float>(0, 0)
    @ObservationIgnored private var tracker = StrokeTracker()
    @ObservationIgnored private var noPath: [CGPoint] = []
    @ObservationIgnored private var noScore = 0.0
    @ObservationIgnored private var whiskTime = 0.0
    @ObservationIgnored private var smoothTime = 0.0
    @ObservationIgnored private var turned = 0.0
    @ObservationIgnored private var lastSound = 0.0
    @ObservationIgnored private var motion: MotionService?
    @ObservationIgnored private var onFinish: ((Int) -> Void)?

    private let whiskSeconds = 12.0
    private let turnGoal = 150.0 * .pi / 180

    var guideText: String {
        switch phase {
        case .whisk:
            if gyro { whiskTime == 0 ? "スマホを手に持って、小さく前後に振ってください" : "シャカシャカ。一定のリズムで" }
            else { whiskTime == 0 ? "指を茶せんに。手首を使って、すばやく前後に" : "シャカシャカ。まっすぐ、一定の速さで" }
        case .smooth: (gyro ? "スマホを机に置いて、指で" : "") + "茶せんを浮かせて、表面をゆっくりなでる。大きな泡をつぶします"
        case .no: "最後に「の」の字を書いて、泡を中央に集める"
        case .lift: "茶せんを、まっすぐ抜きます"
        case .turn, .done: "茶碗(スマホ)を回して、お出しします"
        }
    }

    @ObservationIgnored private var gyro = false
    @ObservationIgnored private var shakes: [Date] = []
    @ObservationIgnored private var shakeSide: Float = 1
    @ObservationIgnored private var lastShake = 0.0
    @ObservationIgnored private var shakeStart: Date?

    func start(style: ChawanStyle, motion: MotionService, gyro: Bool, onFinish: @escaping (Int) -> Void) {
        self.gyro = gyro
        guard scene == nil else { return }
        let tea = TeaScene(style: style)
        scene = tea
        view?.scene = tea.scene
        view?.pointOfView = tea.camera
        self.motion = motion
        self.onFinish = onFinish
        motion.start()
        motion.onTurn = { [weak self] d in self?.addTurn(d) }
        if gyro { motion.setWhiskHandler { [weak self] date in self?.shake(at: date) } }
        // 起動引数 `-demoWhisk YES` で、指の代わりに自動で往復させる(画面確認用)
        if UserDefaults.standard.bool(forKey: "demoWhisk") {
            Task { @MainActor [weak self] in
                var t = 0.0
                while let self, self.link != nil, self.phase == .whisk || self.phase == .smooth {
                    let size = self.view?.bounds.size ?? CGSize(width: 400, height: 800)
                    let y = size.height / 2 + sin(t * 9) * size.height * 0.22
                    self.touchMoved(CGPoint(x: size.width / 2 + sin(t * 1.3) * 60, y: y))
                    t += 1.0 / 60
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
        }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        motion?.onTurn = nil
        motion?.setWhiskHandler(nil)
    }

    /// 振って1回たてた。茶せんを前後の反対側へ動かす(M の字の往復)
    private func shake(at date: Date) {
        guard gyro, phase == .whisk else { return }
        if shakeStart == nil { shakeStart = date }
        shakes.append(date)
        shakeSide = -shakeSide
        lastShake = CACurrentMediaTime()
        tipWorld = SIMD2(Float.random(in: -0.08...0.08), shakeSide * 0.38)
        SoundBank.shared.chasen()
        Haptics.selection()
    }

    // MARK: 指

    func touchMoved(_ p: CGPoint?) {
        touch = p
        guard let p else {
            tipWorld = nil
            tracker.lift()
            if phase == .no { finishNo() }
            return
        }
        tipWorld = worldPoint(p)
        switch phase {
        case .whisk:
            if tracker.add(p) {
                let now = CACurrentMediaTime()
                if now - lastSound > 0.07 { SoundBank.shared.chasen(); lastSound = now }
                Haptics.selection()
            }
        case .no: noPath.append(p)
        default: break
        }
    }

    func rotate(by radians: Double) {
        guard phase == .turn else { return }
        turned = radians
        checkTurn()
    }

    /// 画面の点 → 水面(茶碗の座標)の点
    private func worldPoint(_ p: CGPoint) -> SIMD2<Float>? {
        guard let view else { return nil }
        let a = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 0))
        let b = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 1))
        let t = (TeaScene.liquidY - a.y) / (b.y - a.y)
        var q = SIMD2(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t)
        let maxR = TeaScene.liquidRadius - 0.1
        if simd_length(q) > maxR { q = simd_normalize(q) * maxR }
        return q
    }

    // MARK: 毎フレーム

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = Float(min(0.05, now - last))
        last = now
        guard let scene else { return }

        // 茶筅は指を少し遅れて追う(重さ)。動く向きに傾ける(手首の返し)
        if gyro, phase == .whisk, touch == nil, now - lastShake > 0.35 { tipWorld = nil }
        let target = tipWorld ?? chasenPos
        let prev = chasenPos
        chasenPos += (target - chasenPos) * min(1, dt * 22)
        velocity = velocity * 0.7 + ((chasenPos - prev) / max(dt, 0.001)) * 0.3
        let touching = tipWorld != nil && phase != .lift && phase != .turn && phase != .done
        let y: Float = touching ? TeaScene.liquidY - 0.03 : (phase == .lift || phase == .turn || phase == .done ? 3.2 : TeaScene.liquidY + 0.25)
        let node = scene.chasen
        node.position.x = chasenPos.x
        node.position.z = chasenPos.y
        node.position.y += (y - node.position.y) * min(1, dt * (phase == .lift ? 4 : 14))
        let tilt = simd_clamp(velocity * 0.12, SIMD2(-0.45, -0.45), SIMD2(0.45, 0.45))
        node.eulerAngles.z += (-tilt.x - node.eulerAngles.z) * min(1, dt * 12)
        node.eulerAngles.x += (tilt.y - node.eulerAngles.x) * min(1, dt * 12)

        let mode: FoamSurface.Mode
        switch phase {
        case .whisk: mode = touching ? .whisk : .idle
        case .smooth: mode = touching ? .smooth : .idle
        case .no: mode = touching ? .gather : .idle
        default: mode = .idle
        }
        scene.step(dt: dt, tip: touching ? chasenPos : nil, velocity: velocity, mode: mode)

        switch phase {
        case .whisk:
            if touching, simd_length(velocity) > 0.3 { whiskTime += Double(dt) }
            progress = min(1, whiskTime / whiskSeconds)
            if whiskTime >= whiskSeconds { advance(.smooth) }
        case .smooth:
            if touching { smoothTime += Double(dt) }
            progress = min(1, smoothTime / 5)
            if smoothTime >= 5 || (smoothTime > 2 && scene.coarseness < 0.2) { advance(.no) }
        case .no:
            progress = NoJudge.score(noPath.count > 2 ? noPath : [.zero, .zero, .zero])
        case .lift:
            progress = 1
            if node.position.y > 3.0 { advance(.turn) }
        case .turn:
            progress = min(1, abs(turned) / turnGoal)
            scene.bowlGroup.eulerAngles.y = Float(turned)
        case .done: break
        }
    }

    private func advance(_ next: Phase) {
        phase = next
        progress = 0
        Haptics.success()
    }

    private func finishNo() {
        guard noPath.count > 8 else { noPath = []; return }
        noScore = NoJudge.score(noPath)
        SoundBank.shared.chasen()
        advance(.lift)
    }

    private func addTurn(_ d: Double) {
        guard phase == .turn else { return }
        turned += d
        checkTurn()
    }

    private func checkTurn() {
        guard phase == .turn, abs(turned) >= turnGoal else { return }
        phase = .done
        SoundBank.shared.kakon()
        Haptics.impact()
        let score = gyro
            ? Int(0.85 * Double(TemaeJudge.score(times: shakes, start: shakeStart ?? .now, seconds: whiskSeconds, coverage: nil)) + 15 * noScore)
            : ConcentrationJudge.score(tracker: tracker, noScore: noScore, seconds: whiskSeconds)
        onFinish?(score)
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
        v.accessibilityLabel = "茶碗。指を茶せんにしてたてます"
        return v
    }

    func updateUIView(_ v: TouchSCNView, context: Context) {
        if v.scene == nil, let s = model.scene {
            v.scene = s.scene
            v.pointOfView = s.camera
        }
    }
}

final class TouchSCNView: SCNView {
    weak var model: TemaeModel?
    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchMoved(t.first?.location(in: self)) }
    override func touchesMoved(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchMoved(t.first?.location(in: self)) }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchMoved(nil) }
    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) { model?.touchMoved(nil) }
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

// MARK: - 泡と波

/// 水面の泡と波。指でかき混ぜた場所に泡が生まれ、波紋が広がる。混ぜるほど泡は細かく、全体が淡い色になる。
struct FoamField {
    struct Bubble { var p: CGPoint; var r: CGFloat }
    struct Ripple { var p: CGPoint; var born: Date }

    private(set) var bubbles: [Bubble] = []
    private(set) var ripples: [Ripple] = []
    /// 泡の量(0〜1)。水面全体の色が淡くなる
    private(set) var froth = 0.0
    private var lastRipple = Date.distantPast
    private var rng = SeededRandom(seed: 11)
    var lastTick = Date()

    mutating func stir(at p: CGPoint, strength: Double, center: CGPoint, radius: CGFloat, smooth: Bool = false) {
        froth = min(1, froth + (smooth ? 0 : 0.0016 + strength * 0.002))
        // 混ぜるほど泡は細かくなる
        let size = max(2, 9 - 7 * CGFloat(froth))
        for _ in 0..<(smooth ? 0 : 3) {
            let a = rng.next() * 2 * .pi, d = rng.next() * 26
            let q = CGPoint(x: p.x + cos(a) * d, y: p.y + sin(a) * d)
            guard hypot(q.x - center.x, q.y - center.y) < radius - 4 else { continue }
            bubbles.append(Bubble(p: q, r: size * (0.6 + 0.6 * CGFloat(rng.next()))))
        }
        if bubbles.count > 900 { bubbles.removeFirst(bubbles.count - 900) }
        if Date().timeIntervalSince(lastRipple) > 0.08 {
            ripples.append(Ripple(p: p, born: .now))
            lastRipple = .now
            ripples.removeAll { Date().timeIntervalSince($0.born) > 1.2 }
        }
    }

    /// 「の」の字のあと、泡を細かく整える
    mutating func settle() {
        froth = min(1, froth + 0.15)
        bubbles = bubbles.map { Bubble(p: $0.p, r: max(1.5, $0.r * 0.5)) }
    }

    func draw(in ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, now: Date) {
        let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        // 抹茶の水面。泡が増えるほど淡い色に(グラデーションではなく、単色を重ねる)
        ctx.fill(disk, with: .color(TemaePalette.matcha))
        ctx.fill(disk, with: .color(TemaePalette.foam.opacity(froth * 0.75)))
        ctx.clip(to: disk)
        for b in bubbles {
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - b.r, y: b.p.y - b.r, width: b.r * 2, height: b.r * 2)),
                     with: .color(Theme.Palette.shiro.opacity(0.45)))
        }
        // 波紋: 指の通ったところから輪が広がって消える
        for w in ripples {
            let t = now.timeIntervalSince(w.born)
            guard t < 1.2 else { continue }
            let r = 12 + CGFloat(t) * 90
            ctx.stroke(Path(ellipseIn: CGRect(x: w.p.x - r, y: w.p.y - r, width: r * 2, height: r * 2)),
                       with: .color(Theme.Palette.shiro.opacity(0.35 * (1 - t / 1.2))), lineWidth: 2)
        }
    }
}

// MARK: - 採点

/// 往復の記録。向きが変わるたびに1往復(片道)とし、その片道が直線からどれだけ外れたかを測る
struct StrokeTracker {
    private var points: [CGPoint] = []
    private var direction: CGVector?
    private(set) var strokeTimes: [Date] = []
    /// 片道ごとの離脱率(直線からのずれ / 片道の長さ)
    private(set) var deviations: [Double] = []
    private(set) var speed = 0.0
    private var lastPoint: CGPoint?
    private var lastTime = Date()

    /// 点を足す。片道が終わった(向きが反転した)ら true
    mutating func add(_ p: CGPoint) -> Bool {
        let now = Date()
        if let last = lastPoint {
            let dt = max(0.001, now.timeIntervalSince(lastTime))
            speed = min(1, Double(hypot(p.x - last.x, p.y - last.y)) / dt / 1500)
        }
        lastPoint = p
        lastTime = now
        points.append(p)
        guard points.count >= 3, let first = points.first else { return false }
        let v = CGVector(dx: p.x - first.x, dy: p.y - first.y)
        let length = hypot(v.dx, v.dy)
        guard length > 20 else { return false }
        if let d = direction {
            // 向きが逆になった = 片道が終わった
            let step = CGVector(dx: p.x - points[points.count - 2].x, dy: p.y - points[points.count - 2].y)
            if d.dx * step.dx + d.dy * step.dy < 0 {
                finishStroke(now: now)
                return true
            }
        } else {
            direction = CGVector(dx: v.dx / length, dy: v.dy / length)
        }
        return false
    }

    mutating func lift() {
        points = []
        direction = nil
        lastPoint = nil
    }

    private mutating func finishStroke(now: Date) {
        guard let a = points.first, let b = points.dropLast().last else { return }
        let len = max(1, hypot(b.x - a.x, b.y - a.y))
        // 始点と終点を結ぶ直線から、途中の点がどれだけ離れたか(平均)
        let devs = points.map { p -> Double in
            Double(abs((b.y - a.y) * p.x - (b.x - a.x) * p.y + b.x * a.y - b.y * a.x) / len)
        }
        deviations.append(min(1, (devs.reduce(0, +) / Double(devs.count)) / Double(len) * 4))
        strokeTimes.append(now)
        let last = points.last!
        points = [b, last]
        direction = CGVector(dx: (last.x - b.x), dy: (last.y - b.y))
    }
}

/// 集中度(0〜100)。まっすぐさ50・リズム20・往復の数15・「の」の字15
enum ConcentrationJudge {
    static func score(tracker: StrokeTracker, noScore: Double, seconds: Double) -> Int {
        let straight = tracker.deviations.isEmpty ? 0 : 1 - tracker.deviations.reduce(0, +) / Double(tracker.deviations.count)
        let rhythm = TemaeJudge.steadiness(tracker.strokeTimes)
        let amount = min(1, Double(tracker.strokeTimes.count) / (seconds * 3))
        return Int((50 * straight + 20 * rhythm + 15 * amount + 15 * noScore).rounded())
    }
}

/// 「の」の字らしさ。書いた線がどれだけ回ったか(約1周で満点)
enum NoJudge {
    static func score(_ path: [CGPoint]) -> Double {
        var total = 0.0
        for i in 2..<path.count {
            let a = atan2(path[i - 1].y - path[i - 2].y, path[i - 1].x - path[i - 2].x)
            let b = atan2(path[i].y - path[i - 1].y, path[i].x - path[i - 1].x)
            var d = Double(b - a)
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            total += d
        }
        return min(1, abs(total) / (2 * .pi * 0.9))
    }
}
