import CoreMotion
import Foundation
import Observation

/// 振る(茶筅)と、伏せる(石臼)を検出する。
/// 小さな振り幅でも拾えるように、しきい値は低めにしている(強く振らなくても点てられる)。
@Observable
final class MotionService {
    private let manager = CMMotionManager()
    /// 画面が下を向いているか
    private(set) var isFaceDown = false
    /// センサーが使えるか(シミュレーターでは使えない)
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private var onWhisk: ((Date) -> Void)?
    private var lastWhisk = Date.distantPast
    private var wasAbove = false

    func start(onWhisk: ((Date) -> Void)? = nil) {
        self.onWhisk = onWhisk
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.isFaceDown = motion.gravity.z > 0.8
            let a = motion.userAcceleration
            let r = motion.rotationRate
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let spin = (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot()
            // 振る(加速度)か、回す(ジャイロ)のどちらかがしきい値を越えた瞬間を1回として数える
            // 続けて数えないよう 0.12 秒あける
            let above = magnitude > 0.35 || spin > 3.0
            let now = Date()
            if above, !self.wasAbove, now.timeIntervalSince(self.lastWhisk) > 0.12 {
                self.lastWhisk = now
                self.onWhisk?(now)
            }
            self.wasAbove = above
        }
    }

    func setWhiskHandler(_ handler: ((Date) -> Void)?) { onWhisk = handler }

    func stop() {
        manager.stopDeviceMotionUpdates()
        onWhisk = nil
    }
}

/// 点前の採点(F3)。点数は加点式で出し、言葉は褒め言葉だけ。数字で責めない。
enum TemaeJudge {
    /// 0(ばらばら)〜1(よくそろっている)
    static func steadiness(_ times: [Date]) -> Double {
        let intervals = zip(times.dropFirst(), times).map { $0.timeIntervalSince($1) }.filter { $0 < 1.5 }
        guard intervals.count >= 3 else { return 0.5 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
        let cv = variance.squareRoot() / mean
        return max(0, min(1, 1 - cv))
    }

    /// 途切れずに点て続けたか(1秒ごとに1回以上点てた割合)
    static func continuity(_ times: [Date], from start: Date, seconds: Double) -> Double {
        let slots = Set(times.map { Int($0.timeIntervalSince(start)) }.filter { $0 >= 0 && Double($0) < seconds })
        return Double(slots.count) / seconds
    }

    /// 点数(0〜100)。リズム40・回数30・続ける力20・茶碗全体に行き渡ったか10(指のときだけ。振るときは満点)
    static func score(times: [Date], start: Date, seconds: Double, coverage: Double?) -> Int {
        let rhythm = steadiness(times)
        let amount = min(1, Double(times.count) / 45)
        let keep = continuity(times, from: start, seconds: seconds)
        let spread = coverage ?? 1
        return Int((40 * rhythm + 30 * amount + 20 * keep + 10 * spread).rounded())
    }

    static func praise(for score: Int) -> (title: String, note: String) {
        switch score {
        case 90...: ("見事なお点前で", "振るリズムが、ぴたりとそろっていました")
        case 70...: ("結構なお点前で", "落ち着いたリズムで、きめ細かく点ちました")
        default: ("心のこもったお点前で", "あなたの一服です。ゆっくり味わいましょう")
        }
    }
}
