import DesignSystem
import SwiftUI

/// りきゅうさんの後ろの小さな茶室(五月人形・お雛様の飾り台のような、背中のまわりだけの背景)。
/// 参考写真(chashitsu.jpg)の 床の間・畳の床・奥の壁 を、フラットな絵で描く(写真そのものは使わない)。
/// - 奥の壁: 土壁の色。右側に床の間(少し暗いくぼみ)と床柱、掛け軸、花入れ
/// - 床: 手前へ広がる畳。黒い畳縁の線と、壁との境の木(畳寄せ)
/// 影・光沢・グラデーションは使わない。
struct ChashitsuBackdrop: View {
    private let wall = Color(red: 0.80, green: 0.70, blue: 0.53)
    private let alcove = Color(red: 0.70, green: 0.60, blue: 0.44)
    private let wood = Color(red: 0.28, green: 0.20, blue: 0.14)
    private let tatami = Color(red: 0.80, green: 0.76, blue: 0.56)
    private let tatamiLine = Color(red: 0.66, green: 0.62, blue: 0.44)
    private let heri = Color(red: 0.16, green: 0.13, blue: 0.11)
    private let paper = Color(red: 0.93, green: 0.90, blue: 0.82)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let floorTop = h * 0.62                   // 壁と床の境
            let inset = w * 0.16                      // 床の奥の辺を内側へ(奥行き)

            // 奥の壁
            ctx.fill(Path(CGRect(x: inset, y: 0, width: w - inset * 2, height: floorTop)), with: .color(wall))
            // 上の長押(なげし)
            ctx.fill(Path(CGRect(x: inset, y: h * 0.06, width: w - inset * 2, height: h * 0.025)), with: .color(wood))

            // 床の間(右寄りのくぼみ)と床柱
            let alcoveRect = CGRect(x: w * 0.50, y: h * 0.09, width: w - inset - w * 0.50, height: floorTop - h * 0.09 - h * 0.035)
            ctx.fill(Path(alcoveRect), with: .color(alcove))
            ctx.fill(Path(CGRect(x: alcoveRect.minX - 6, y: h * 0.085, width: 7, height: floorTop - h * 0.085)), with: .color(wood))
            // 床の間の板(床框)
            ctx.fill(Path(CGRect(x: alcoveRect.minX, y: alcoveRect.maxY, width: alcoveRect.width, height: h * 0.035)), with: .color(wood))

            // 掛け軸
            let scroll = CGRect(x: alcoveRect.midX - w * 0.05, y: alcoveRect.minY + h * 0.03, width: w * 0.10, height: alcoveRect.height * 0.74)
            ctx.fill(Path(scroll), with: .color(Color(red: 0.62, green: 0.50, blue: 0.30)))
            ctx.fill(Path(scroll.insetBy(dx: scroll.width * 0.16, dy: scroll.height * 0.12)), with: .color(paper))
            // 掛け軸の山水(墨の線を2本だけ)
            var hills = Path()
            let inner = scroll.insetBy(dx: scroll.width * 0.16, dy: scroll.height * 0.12)
            hills.move(to: CGPoint(x: inner.minX, y: inner.midY + inner.height * 0.15))
            hills.addQuadCurve(to: CGPoint(x: inner.maxX, y: inner.midY), control: CGPoint(x: inner.midX, y: inner.minY + inner.height * 0.2))
            hills.move(to: CGPoint(x: inner.minX, y: inner.maxY - inner.height * 0.15))
            hills.addQuadCurve(to: CGPoint(x: inner.maxX, y: inner.maxY - inner.height * 0.25), control: CGPoint(x: inner.midX, y: inner.midY + inner.height * 0.05))
            ctx.stroke(hills, with: .color(wood.opacity(0.55)), lineWidth: 1.2)
            ctx.fill(Path(CGRect(x: scroll.minX - 2, y: scroll.maxY - 3, width: scroll.width + 4, height: 4)), with: .color(wood))

            // 花入れと枝
            let vase = CGRect(x: alcoveRect.minX + alcoveRect.width * 0.12, y: alcoveRect.maxY - h * 0.07, width: w * 0.025, height: h * 0.07)
            ctx.fill(Path(roundedRect: vase, cornerRadius: 2), with: .color(Color(red: 0.55, green: 0.24, blue: 0.16)))
            var branch = Path()
            branch.move(to: CGPoint(x: vase.midX, y: vase.minY))
            branch.addQuadCurve(to: CGPoint(x: vase.midX + 10, y: vase.minY - h * 0.10), control: CGPoint(x: vase.midX - 6, y: vase.minY - h * 0.05))
            ctx.stroke(branch, with: .color(Theme.Palette.matcha), lineWidth: 1.5)
            for k in 0..<4 {
                let p = CGPoint(x: vase.midX + CGFloat(k) * 3 - 2, y: vase.minY - h * 0.03 - CGFloat(k) * h * 0.02)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 2, width: 6, height: 4)), with: .color(Theme.Palette.matcha))
            }

            // 左の障子(明かり)
            let shoji = CGRect(x: inset + w * 0.04, y: h * 0.16, width: w * 0.22, height: floorTop - h * 0.24)
            ctx.fill(Path(shoji), with: .color(paper))
            ctx.stroke(Path(shoji), with: .color(wood), lineWidth: 2)
            for k in 1..<3 {
                let x = shoji.minX + shoji.width * CGFloat(k) / 3
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: shoji.minY)); $0.addLine(to: CGPoint(x: x, y: shoji.maxY)) }, with: .color(wood.opacity(0.6)), lineWidth: 1)
            }
            for k in 1..<4 {
                let y = shoji.minY + shoji.height * CGFloat(k) / 4
                ctx.stroke(Path { $0.move(to: CGPoint(x: shoji.minX, y: y)); $0.addLine(to: CGPoint(x: shoji.maxX, y: y)) }, with: .color(wood.opacity(0.6)), lineWidth: 1)
            }

            // 床(手前へ広がる畳)
            var floor = Path()
            floor.move(to: CGPoint(x: inset, y: floorTop))
            floor.addLine(to: CGPoint(x: w - inset, y: floorTop))
            floor.addLine(to: CGPoint(x: w, y: h))
            floor.addLine(to: CGPoint(x: 0, y: h))
            floor.closeSubpath()
            ctx.fill(floor, with: .color(tatami))
            // 畳の目(細い横線)
            for k in 1..<8 {
                let t = CGFloat(k) / 8
                let y = floorTop + (h - floorTop) * t * t
                let x0 = inset * (1 - t * t) , x1 = w - inset * (1 - t * t)
                ctx.stroke(Path { $0.move(to: CGPoint(x: x0, y: y)); $0.addLine(to: CGPoint(x: x1, y: y)) }, with: .color(tatamiLine), lineWidth: 0.6)
            }
            // 畳縁(黒い線。奥から手前へ広がる)
            for fx in [0.36, 0.64] {
                let top = CGPoint(x: inset + (w - inset * 2) * fx, y: floorTop)
                let bottom = CGPoint(x: w * fx, y: h)
                ctx.stroke(Path { $0.move(to: top); $0.addLine(to: bottom) }, with: .color(heri), lineWidth: 3)
            }
            // 畳寄せ(壁と床の境の木)
            ctx.fill(Path(CGRect(x: inset, y: floorTop - 3, width: w - inset * 2, height: 4)), with: .color(wood))
            // 左右の柱(この飾りの枠)
            ctx.fill(Path(CGRect(x: inset - 6, y: 0, width: 7, height: floorTop + 1)), with: .color(wood))
            ctx.fill(Path(CGRect(x: w - inset - 1, y: 0, width: 7, height: floorTop + 1)), with: .color(wood))
        }
        .clipShape(.rect(cornerRadius: Theme.Radius.l))
        .accessibilityHidden(true)
    }
}
