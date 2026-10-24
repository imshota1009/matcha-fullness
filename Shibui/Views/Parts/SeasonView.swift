import DesignSystem
import SwiftUI

/// 季節。今日の日付から決まる(設定のデモで切り替えられる)
enum Season: String, CaseIterable, Identifiable {
    case spring, summer, autumn, winter
    var id: Self { self }

    static let storageKey = "seasonOverride"

    /// 設定で選んだ季節。「自動」なら今日の月から
    static var current: Season {
        if let raw = UserDefaults.standard.string(forKey: storageKey), let s = Season(rawValue: raw) { return s }
        switch Calendar.current.component(.month, from: .now) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    var name: String {
        switch self {
        case .spring: "春"
        case .summer: "夏"
        case .autumn: "秋"
        case .winter: "冬"
        }
    }

    /// 茶室のひとこと
    var line: String {
        switch self {
        case .spring: "春の茶室。桜がひとひら、うぐいすの声"
        case .summer: "夏の茶室。風鈴が、ちりんと鳴ります"
        case .autumn: "秋の茶室。もみじと、鈴虫の声"
        case .winter: "冬の茶室。雪が舞い、釜の湯がしずかに鳴ります"
        }
    }
}

/// 季節の景色。花びら・もみじ・雪がゆっくり落ち、夏は風鈴がゆれる。
/// 色は落ち着いたものだけ。数は少なく、うしろで静かに動く(操作のじゃまをしない)。
struct SeasonLayer: View {
    var season = Season.current
    /// 落ちてくるものの数
    var count = 9

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                switch season {
                case .summer: drawFurin(&ctx, size: size, t: t)
                default: drawFalling(&ctx, size: size, t: t)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawFalling(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<count {
            let seed = Double(i) * 12.9898
            let speed = season == .winter ? 22 + fract(sin(seed) * 437) * 18 : 16 + fract(sin(seed) * 437) * 14
            let period = (size.height + 80) / speed
            let phase = fract(t / period + fract(sin(seed * 3.1) * 91))
            let y = -40 + phase * (size.height + 80)
            let baseX = fract(sin(seed * 7.7) * 573) * size.width
            let x = baseX + sin(t * 0.6 + seed) * 26
            let angle = Angle.radians(t * 0.8 + seed)
            var c = ctx
            c.translateBy(x: x, y: y)
            c.rotate(by: angle)
            switch season {
            case .spring:
                // 桜の花びら(先が少しへこんだ楕円)
                let p = Path { p in
                    p.move(to: CGPoint(x: 0, y: -7))
                    p.addQuadCurve(to: CGPoint(x: 0, y: 8), control: CGPoint(x: 9, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 0, y: -7), control: CGPoint(x: -9, y: 0))
                }
                c.fill(p, with: .color(Color(red: 0.92, green: 0.77, blue: 0.78).opacity(0.85)))
            case .autumn:
                // もみじ(5つの先がある葉)
                var p = Path()
                for k in 0..<10 {
                    let r: CGFloat = k % 2 == 0 ? 11 : 4.5
                    let a = Double(k) / 10 * 2 * .pi - .pi / 2
                    let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
                    k == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
                p.closeSubpath()
                c.fill(p, with: .color(Color(red: 0.72, green: 0.38, blue: 0.24).opacity(0.8)))
            default:
                // 雪
                c.fill(Path(ellipseIn: CGRect(x: -3.5, y: -3.5, width: 7, height: 7)), with: .color(Theme.Palette.hai.opacity(0.35)))
            }
        }
    }

    /// 夏: 右上につるした風鈴が、風でゆれる
    private func drawFurin(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let swing = sin(t * 1.3) * 0.16 + sin(t * 0.47) * 0.06
        var c = ctx
        c.translateBy(x: size.width - 44, y: 104)  // 上のボタンにかからない高さから吊るす
        c.rotate(by: .radians(swing))
        let ink = Theme.Palette.kogecha
        c.stroke(Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 0, y: 34)) }, with: .color(ink.opacity(0.6)), lineWidth: 1.5)
        // ガラスの鐘(半円)
        let bell = Path { p in
            p.addArc(center: CGPoint(x: 0, y: 52), radius: 18, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.closeSubpath()
        }
        c.fill(bell, with: .color(Theme.Palette.shiro))
        c.stroke(bell, with: .color(ink.opacity(0.7)), lineWidth: 1.5)
        c.fill(Path(CGRect(x: -18, y: 46, width: 36, height: 3)), with: .color(Theme.Palette.matcha.opacity(0.8)))
        // 短冊
        c.stroke(Path { $0.move(to: CGPoint(x: 0, y: 52)); $0.addLine(to: CGPoint(x: 0, y: 70)) }, with: .color(ink.opacity(0.6)), lineWidth: 1)
        c.rotate(by: .radians(swing * 1.6))
        c.fill(Path(CGRect(x: -7, y: 70, width: 14, height: 34)), with: .color(Theme.Palette.matcha.opacity(0.85)))
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }
}
