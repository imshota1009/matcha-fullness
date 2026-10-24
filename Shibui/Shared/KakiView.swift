import SwiftUI

/// 柿の絵。絵文字を使わず図形で描く。熟すほど 青い渋柿 → 橙 → 干し柿の茶 に変わり、少し縮んでしわが入る。
/// グラデーションは使わず、段階ごとの単色を補間する。
struct KakiView: View {
    var ripeness: Double
    var size: CGFloat = 56
    /// 上にひもを描くか(軒下に吊るす表現)
    var showsString = false

    var body: some View {
        VStack(spacing: 0) {
            if showsString {
                Rectangle()
                    .fill(Color(white: 0.55))
                    .frame(width: 1.5, height: size * 0.35)
            }
            ZStack(alignment: .top) {
                Ellipse()
                    .fill(Self.color(for: ripeness))
                    .frame(width: size * scale, height: size * scale * 0.86)
                    .overlay {
                        if ripeness >= 1 { Wrinkles().stroke(.black.opacity(0.18), lineWidth: max(1, size * 0.025)) }
                    }
                    .padding(.top, size * 0.12)
                Calyx()
                    .fill(Self.calyxColor(for: ripeness))
                    .frame(width: size * 0.5, height: size * 0.24)
            }
            .frame(width: size, height: size)
        }
        .animation(.spring(duration: 0.6), value: ripeness)
        .accessibilityHidden(true)
    }

    private var scale: CGFloat { 1 - 0.12 * ripeness }

    static func color(for r: Double) -> Color {
        let green = (0.47, 0.58, 0.27), orange = (0.93, 0.52, 0.16), dried = (0.62, 0.30, 0.13)
        let (a, b, t) = r < 0.6 ? (green, orange, r / 0.6) : (orange, dried, (r - 0.6) / 0.4)
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }

    static func calyxColor(for r: Double) -> Color {
        r < 0.6 ? Color(red: 0.25, green: 0.38, blue: 0.16) : Color(red: 0.30, green: 0.22, blue: 0.12)
    }
}

/// へた(4枚の葉)
private struct Calyx: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.maxY * 0.7)
        for dx in [-0.5, -0.22, 0.22, 0.5] {
            let tip = CGPoint(x: rect.midX + rect.width * dx, y: rect.maxY)
            p.move(to: c)
            p.addQuadCurve(to: tip, control: CGPoint(x: (c.x + tip.x) / 2, y: rect.minY + rect.height * 0.35))
            p.addQuadCurve(to: c, control: CGPoint(x: (c.x + tip.x) / 2, y: rect.maxY + rect.height * 0.1))
        }
        p.addRoundedRect(in: CGRect(x: rect.midX - rect.width * 0.05, y: rect.minY, width: rect.width * 0.1, height: rect.height * 0.7), cornerSize: CGSize(width: 2, height: 2))
        return p
    }
}

/// 干し柿のしわ
private struct Wrinkles: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (y, w) in [(0.42, 0.5), (0.6, 0.62), (0.76, 0.44)] {
            let yy = rect.minY + rect.height * y
            p.move(to: CGPoint(x: rect.midX - rect.width * w / 2, y: yy))
            p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * w / 2, y: yy), control: CGPoint(x: rect.midX, y: yy + rect.height * 0.06))
        }
        return p
    }
}

#Preview {
    HStack {
        ForEach([0, 0.3, 0.6, 0.85, 1], id: \.self) { KakiView(ripeness: $0, showsString: true) }
    }
}
