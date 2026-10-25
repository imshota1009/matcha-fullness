import DesignSystem
import SwiftUI

/// タイマーの地面の枯山水(白い砂利に熊手でつけた筋、石、苔)。地面と同じ平面に寝かせて置く(斜めに倒すのは呼び出し側)。
/// - 砂紋: 平行な筋(さざ波)と、石と水たまりのまわりの同心円の筋(水紋)
/// - 石: 灰の大小2つ、まわりに苔(抹茶色)
/// フラットな線と面だけで描く(影・グラデーションなし)。
struct KaresansuiGround: View {
    /// 水たまりの中心と半径(このビューの座標)。まわりに同心円の筋をつける
    var pondCenter: CGPoint
    var pondRadius: CGFloat

    private let sand = Color(red: 0.93, green: 0.91, blue: 0.86)
    private let groove = Color(red: 0.80, green: 0.77, blue: 0.70)
    private let stone = Color(red: 0.47, green: 0.45, blue: 0.43)
    private let stoneDark = Color(red: 0.36, green: 0.34, blue: 0.32)
    private let moss = Color(red: 0.42, green: 0.52, blue: 0.27)

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sand))
            // 石の位置(水たまりと重ならないところ)
            let stones: [(CGPoint, CGFloat)] = [
                (CGPoint(x: size.width * 0.30, y: size.height * 0.36), size.width * 0.045),
                (CGPoint(x: size.width * 0.70, y: size.height * 0.62), size.width * 0.032),
            ]
            // 水紋(同心円)を描く場所: 水たまりと石のまわり
            let rings: [(CGPoint, CGFloat, Int)] = [(pondCenter, pondRadius + 10, 4)] + stones.map { ($0.0, $0.1 + 10, 4) }
            // 平行な筋(さざ波)。同心円の内側には描かない
            let spacing: CGFloat = 13
            var y: CGFloat = spacing / 2
            while y < size.height {
                var path = Path()
                var x: CGFloat = 0
                var drawing = false
                while x <= size.width {
                    let p = CGPoint(x: x, y: y + sin(x / 38) * 2)
                    let blocked = rings.contains { hypot(p.x - $0.0.x, p.y - $0.0.y) < $0.1 + CGFloat($0.2) * spacing }
                    if blocked { drawing = false }
                    else if drawing { path.addLine(to: p) }
                    else { path.move(to: p); drawing = true }
                    x += 4
                }
                ctx.stroke(path, with: .color(groove), lineWidth: 1.6)
                y += spacing
            }
            // 同心円の筋(水紋)
            for (c, r0, n) in rings {
                for k in 0..<n {
                    let r = r0 + CGFloat(k) * spacing
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(groove), lineWidth: 1.6)
                }
            }
            // 苔と石
            for (c, r) in stones {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.35, y: c.y - r * 1.15, width: r * 2.7, height: r * 2.3)), with: .color(moss))
                var rock = Path()
                rock.move(to: CGPoint(x: c.x - r, y: c.y + r * 0.3))
                rock.addQuadCurve(to: CGPoint(x: c.x + r * 0.1, y: c.y - r * 0.9), control: CGPoint(x: c.x - r * 0.9, y: c.y - r * 0.7))
                rock.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y + r * 0.2), control: CGPoint(x: c.x + r * 0.9, y: c.y - r * 0.6))
                rock.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y + r * 0.3), control: CGPoint(x: c.x, y: c.y + r * 0.8))
                ctx.fill(rock, with: .color(stone))
                ctx.stroke(rock, with: .color(stoneDark), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}
