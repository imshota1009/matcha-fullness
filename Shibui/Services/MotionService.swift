import CoreMotion
import Foundation
import Observation

/// 机に置いているか(SPEC 5章「机置き判定」)と、茶碗(iPhone)を回した角度(ヨー)を検出する。
@Observable
final class MotionService {
    private let manager = CMMotionManager()
    /// 机に置いている = 画面が上向き かつ 直近 0.5 秒の揺れが小さい
    private(set) var isOnDesk = true
    /// 回した角度(ラジアン)。連続した値(1周をこえても飛ばない)。反時計回りが正(CoreMotion の向き)
    private(set) var yaw = 0.0
    /// センサーが使えるか(シミュレーターでは使えない)
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private var shakes: [(t: Double, a2: Double)] = []
    private var lastRawYaw: Double?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // 揺れ: ユーザー加速度の大きさの二乗を、直近 0.5 秒ぶん持つ
            let a = motion.userAcceleration
            let t = motion.timestamp
            shakes.append((t, a.x * a.x + a.y * a.y + a.z * a.z))
            shakes.removeAll { t - $0.t > TemaeConstants.deskWindow }
            let rms = (shakes.map(\.a2).reduce(0, +) / Double(max(1, shakes.count))).squareRoot()
            isOnDesk = motion.gravity.z <= TemaeConstants.deskGravityZ && rms <= TemaeConstants.deskShakeRMS
            // ヨー: -π〜π の値をつなげて、連続した角度にする
            let raw = motion.attitude.yaw
            if let last = lastRawYaw {
                var d = raw - last
                if d > .pi { d -= 2 * .pi }
                if d < -.pi { d += 2 * .pi }
                yaw += d
            }
            lastRawYaw = raw
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        lastRawYaw = nil
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
        case 90...: ("見事な一杯です", "振るリズムが、ぴたりとそろっていました")
        case 70...: ("上手な一杯です", "落ち着いたリズムで、きめ細かくたちました")
        default: ("心のこもった一杯です", "あなたの一杯です。ゆっくり味わいましょう")
        }
    }
}
