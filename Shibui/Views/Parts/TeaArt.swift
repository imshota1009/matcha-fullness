import DesignSystem
import SwiftUI

// 茶室の絵。絵文字や画像を使わず、4色(抹茶・焦茶・白・灰)の図形で描く。グラデーションは使わない。

/// 茶碗。上から見た形で、抹茶の水面に泡が立つ。茶碗は設定で選んだ種類(Unity で作った画像)を使う。
struct ChawanView: View {
    /// 0(泡なし)〜1(きめ細かい泡でいっぱい)
    var foam: Double
    /// 泡の粒の細かさ。整えるほど細かく(0〜1)
    var smoothness: Double = 0
    var size: CGFloat = 240
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino

    var body: some View {
        let liquid = size * ChawanSpec.liquid / ChawanSpec.imageExtent
        ZStack {
            Image(style.imageName).resizable().frame(width: size, height: size)
            Circle().fill(Theme.Palette.matcha).frame(width: liquid, height: liquid)
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = canvasSize.width / 2
                let count = Int(foam * 160)
                var rng = SeededRandom(seed: 7)
                for _ in 0..<count {
                    let angle = rng.next() * 2 * .pi
                    let r = radius * (rng.next().squareRoot() * 0.92)
                    let base = 2 + rng.next() * 5
                    let dot = base * (1 - 0.6 * smoothness) * size / 240
                    let p = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2)),
                                 with: .color(Theme.Palette.shiro.opacity(0.55)))
                }
            }
            .frame(width: liquid, height: liquid)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.3), value: foam)
        .accessibilityHidden(true)
    }
}

/// 泡の位置を毎回同じにするための乱数(描き直しても泡が暴れない)
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

