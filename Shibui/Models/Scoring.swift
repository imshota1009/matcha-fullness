import Foundation

/// 所作の採点(SPEC 5章「採点の計算式」)。記録した指の軌跡から、理想の所作からの離れ具合を計算する。
/// 座標は茶碗の中心が原点、内側の半径が 1。y が画面の縦方向(奥⇔手前)。
enum Scoring {
    struct Sample { var p: SIMD2<Double>; var t: Double }
    struct Stroke { var length: Double; var duration: Double; var sideRatio: Double }

    static func clamp(_ a: Double) -> Double { min(1, max(0, a)) }

    /// 1回のタッチの軌跡を、y の速さの符号が変わる点で区切る。長さが足りないものは捨てる
    static func strokes(in samples: [Sample]) -> [Stroke] {
        guard samples.count >= 3 else { return [] }
        var result: [Stroke] = []
        var start = 0
        var sign = 0.0
        for i in 1..<samples.count {
            let dy = samples[i].p.y - samples[i - 1].p.y
            guard dy != 0 else { continue }
            let s: Double = dy > 0 ? 1 : -1
            if sign != 0, s != sign {
                if let k = make(samples[start...(i - 1)]) { result.append(k) }
                start = i - 1
            }
            sign = s
        }
        if let k = make(samples[start...]) { result.append(k) }
        return result
    }

    private static func make(_ seg: ArraySlice<Sample>) -> Stroke? {
        guard let a = seg.first, let b = seg.last else { return nil }
        let length = abs(b.p.y - a.p.y)
        guard length >= TemaeConstants.minStrokeLength else { return nil }
        let xs = seg.map(\.p.x)
        let mean = xs.reduce(0, +) / Double(xs.count)
        let sd = (xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count)).squareRoot()
        return Stroke(length: length, duration: b.t - a.t, sideRatio: sd / length)
    }

    struct Foam { var line: Double; var rhythm: Double; var count: Double; var foam: Double }

    /// 泡スコア F と、その3要素。`window` が指定されたら直近のストロークだけで直線性・リズムを計算する(量は全数)
    static func foam(_ all: [Stroke], window: Int? = nil) -> Foam {
        let ks = window.map { Array(all.suffix($0)) } ?? all
        let n = ks.count
        var line = 0.0, rhythm = 0.0
        if n >= 3 {
            let e = ks.map(\.sideRatio).reduce(0, +) / Double(n)
            line = 100 * clamp((TemaeConstants.lineWorst - e) / (TemaeConstants.lineWorst - TemaeConstants.lineBest))
            let mu = ks.map(\.duration).reduce(0, +) / Double(n)
            let sd = (ks.map { ($0.duration - mu) * ($0.duration - mu) }.reduce(0, +) / Double(n)).squareRoot()
            let cv = mu > 0 ? sd / mu : 1
            rhythm = 100 * clamp((TemaeConstants.rhythmWorst - cv) / (TemaeConstants.rhythmWorst - TemaeConstants.rhythmBest))
        }
        let count = 100 * min(Double(all.count) / Double(TemaeConstants.targetStrokes), 1)
        let f = TemaeConstants.weightLine * line + TemaeConstants.weightRhythm * rhythm + TemaeConstants.weightCount * count
        return Foam(line: line, rhythm: rhythm, count: count, foam: f)
    }

    /// 仕上げ: 回転の合計(度)と平均の速さ(半径/秒)
    static func finishMeasure(_ samples: [Sample]) -> (degrees: Double, speed: Double) {
        guard samples.count >= 3 else { return (0, 0) }
        var total = 0.0, length = 0.0
        var prev: Double?
        for i in 1..<samples.count {
            let d = samples[i].p - samples[i - 1].p
            let len = (d.x * d.x + d.y * d.y).squareRoot()
            length += len
            guard len > 0.002 else { continue }
            let th = atan2(d.y, d.x)
            if let p = prev {
                var w = th - p
                while w > .pi { w -= 2 * .pi }
                while w < -.pi { w += 2 * .pi }
                total += w
            }
            prev = th
        }
        let time = max(0.001, samples.last!.t - samples.first!.t)
        return (abs(total) * 180 / .pi, length / time)
    }

    static func finishScore(degrees: Double, speed: Double) -> Double {
        let a = min(degrees / TemaeConstants.finishDegrees, 1)
        let g = speed <= TemaeConstants.finishSlow ? 1 : clamp((TemaeConstants.finishFast - speed) / (TemaeConstants.finishFast - TemaeConstants.finishSlow))
        return 100 * a * g
    }

    static func rotateScore(_ angles: [Double]) -> Double {
        guard !angles.isEmpty else { return 0 }
        let s = angles.map { clamp(1 - abs($0 - TemaeConstants.rotateTarget) / TemaeConstants.rotateZeroAt) }
        return 100 * s.reduce(0, +) / Double(TemaeConstants.rotateTimes)
    }

    static func total(foam: Double, finish: Double, rotate: Double) -> Int {
        Int((TemaeConstants.weightFoam * foam + TemaeConstants.weightFinish * finish + TemaeConstants.weightRotate * rotate).rounded())
    }
}

/// 点前の結果(記録と結果画面に渡す)
struct TemaeResult {
    var score: Int
    var foam: Int
    var line: Int
    var rhythm: Int
    var count: Int
    var finish: Int
    var rotate: Int
}
