import DesignSystem
import SwiftUI

/// 点前(指で点てる)。スマホを机に置き、画面を茶碗の水面に見立てて、指を茶筅として点てる。
/// 1. 往復: 直線の往復で泡を立てる(約15秒)。直線からどれだけ外れたか(離脱率)を測る
/// 2. 「の」の字: 最後に「の」の字を書いて、茶筅を抜く
/// 3. 回す: 茶碗(iPhone)を机の上で回してお出しする。回したことをセンサーで感知して終わる
/// うまさは「集中度」(0〜100)として返す。
/// 見た目はフラット: 畳色の背景、Unity で作った茶碗(単色)、抹茶の水面、泡と波は単色の図形。
struct TemaeView: View {
    let motion: MotionService
    let onFinish: (_ score: Int) -> Void
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino

    enum Phase { case whisk, no, turn }
    @State private var phase = Phase.whisk
    @State private var foam = FoamField()
    @State private var tip: CGPoint?
    @State private var tracker = StrokeTracker()
    @State private var noPath: [CGPoint] = []
    @State private var noScore = 0.0
    @State private var turned = 0.0
    @State private var startedAt: Date?

    private let whiskSeconds = 15.0
    /// 回したとみなす角度(約150度。茶碗を2回に分けて回すくらい)
    private let turnGoal = 150.0 * .pi / 180

    var body: some View {
        GeometryReader { geo in
            // 茶碗は、上のダイナミックアイランドにかからない範囲で最大。左右ははみ出してよい
            let topInset = geo.safeAreaInsets.top + 8
            let diameter = geo.size.height + geo.safeAreaInsets.bottom - topInset * 2
            let center = CGPoint(x: geo.size.width / 2, y: topInset + diameter / 2 - geo.safeAreaInsets.top)
            let liquidRadius = diameter / 2 * ChawanSpec.liquid / ChawanSpec.imageExtent

            ZStack {
                TemaePalette.tatami.ignoresSafeArea()

                Image(style.imageName)
                    .resizable()
                    .frame(width: diameter, height: diameter)
                    .position(center)
                    .rotationEffect(.radians(-turned), anchor: UnitPoint(x: center.x / geo.size.width, y: center.y / geo.size.height))

                TimelineView(.animation) { context in
                    Canvas { ctx, _ in
                        foam.draw(in: &ctx, center: center, radius: liquidRadius, now: context.date)
                        if phase == .no, noPath.count > 1 {
                            var p = Path()
                            p.addLines(noPath)
                            ctx.stroke(p, with: .color(TemaePalette.foam.opacity(0.9)), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                .allowsHitTesting(false)

                if let tip {
                    // Unity で作った茶筅(真上から)。指の位置に出す
                    Image("ChasenTop").resizable().frame(width: 120, height: 120).position(tip).allowsHitTesting(false)
                }

                guide
                    .position(x: geo.size.width / 2, y: geo.size.height - 40)
            }
            .contentShape(.rect)
            .gesture(drag(center: center, radius: liquidRadius))
            .simultaneousGesture(rotate)
            .onChange(of: foam.lastTick) { _, _ in checkTime() }
        }
        .onAppear {
            motion.start()
            motion.onTurn = { delta in addTurn(delta) }
        }
        .onDisappear { motion.onTurn = nil }
    }

    // MARK: - 案内

    private var guide: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(guideText)
                .font(.headline)
                .foregroundStyle(TemaePalette.ink)
            if phase == .turn {
                Capsule().fill(TemaePalette.ink.opacity(0.2)).frame(width: 160, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(TemaePalette.ink).frame(width: 160 * min(1, abs(turned) / turnGoal), height: 4)
                    }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(TemaePalette.tatami.opacity(0.9), in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private var guideText: String {
        switch phase {
        case .whisk: startedAt == nil ? "指を茶筅に。まっすぐ前後に往復させて" : "シャカシャカ。まっすぐ、一定の速さで"
        case .no: "最後に「の」の字を書いて、茶筅を抜く"
        case .turn: motion.isAvailable ? "茶碗(スマホ)を回して、お出しします" : "二本指で茶碗を回して、お出しします"
        }
    }

    // MARK: - 指の動き

    private func drag(center: CGPoint, radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let p = value.location
                guard hypot(p.x - center.x, p.y - center.y) < radius * 1.05 else { tip = nil; return }
                tip = p
                switch phase {
                case .whisk:
                    if startedAt == nil { startedAt = .now }
                    if tracker.add(p) {
                        SoundBank.shared.chasen()
                        Haptics.selection()
                    }
                    foam.stir(at: p, strength: tracker.speed, center: center, radius: radius)
                case .no:
                    noPath.append(p)
                    foam.stir(at: p, strength: 0.3, center: center, radius: radius, smooth: true)
                case .turn:
                    break
                }
                foam.lastTick = .now
            }
            .onEnded { _ in
                tip = nil
                tracker.lift()
                if phase == .no { finishNo() }
            }
    }

    /// 二本指で回す(センサーがないときの代わり)
    private var rotate: some Gesture {
        RotateGesture()
            .onChanged { value in
                guard phase == .turn else { return }
                turned = value.rotation.radians
                if abs(turned) >= turnGoal { finishTurn() }
            }
    }

    private func checkTime() {
        if phase == .whisk, let startedAt, Date().timeIntervalSince(startedAt) >= whiskSeconds {
            withAnimation { phase = .no }
            Haptics.success()
        }
    }

    private func finishNo() {
        guard noPath.count > 8 else { noPath = []; return }
        noScore = NoJudge.score(noPath)
        foam.settle()
        SoundBank.shared.chasen()
        Haptics.success()
        withAnimation { phase = .turn }
    }

    private func addTurn(_ delta: Double) {
        guard phase == .turn else { return }
        turned += delta
        if abs(turned) >= turnGoal { finishTurn() }
    }

    private func finishTurn() {
        guard phase == .turn else { return }
        phase = .whisk  // 二重に終わらないように
        SoundBank.shared.kakon()
        Haptics.impact()
        let score = ConcentrationJudge.score(tracker: tracker, noScore: noScore, seconds: whiskSeconds)
        onFinish(score)
    }
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
