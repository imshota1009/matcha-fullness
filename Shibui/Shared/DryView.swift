import SwiftUI

/// 干している物の絵。種類に合わせて干し芋か干し柿を描く。
struct DryView: View {
    var kind: Kaki.Kind
    var ripeness: Double
    var size: CGFloat = 56
    var showsString = false

    var body: some View {
        switch kind {
        case .imo: ImoView(ripeness: ripeness, size: size, showsString: showsString)
        case .kaki: KakiView(ripeness: ripeness, size: size, showsString: showsString)
        }
    }
}

/// 干し芋の絵。絵文字を使わず図形で描く。
/// 干すほど 紫の皮のさつまいも → 黄色の蒸し芋 → 飴色の干し芋 に変わり、薄く平たくなる。食べごろには白い粉(糖の結晶)が吹く。
struct ImoView: View {
    var ripeness: Double
    var size: CGFloat = 56
    var showsString = false

    var body: some View {
        VStack(spacing: 0) {
            if showsString {
                Rectangle()
                    .fill(Color(white: 0.55))
                    .frame(width: 1.5, height: size * 0.35)
            }
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.16 * (1 - ripeness * 0.5), style: .continuous)
                    .fill(Self.color(for: ripeness))
                    .frame(width: size * 0.42, height: size * (0.92 - 0.08 * ripeness))
                    .overlay {
                        // 皮のすじ(生のうちだけ)
                        if ripeness < 0.5 {
                            Capsule().fill(.black.opacity(0.12)).frame(width: size * 0.04, height: size * 0.5)
                        }
                    }
                if ripeness >= 1 {
                    SugarDots().fill(.white.opacity(0.8))
                        .frame(width: size * 0.36, height: size * 0.8)
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(showsString ? 0 : -18))
        }
        .animation(.spring(duration: 0.6), value: ripeness)
        .accessibilityHidden(true)
    }

    static func color(for r: Double) -> Color {
        let raw = (0.56, 0.24, 0.38), steamed = (0.93, 0.76, 0.32), dried = (0.80, 0.50, 0.18)
        let (a, b, t) = r < 0.5 ? (raw, steamed, r / 0.5) : (steamed, dried, (r - 0.5) / 0.5)
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
}

/// 干し芋の白い粉
private struct SugarDots: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let points: [(Double, Double)] = [(0.3, 0.15), (0.7, 0.28), (0.4, 0.45), (0.65, 0.6), (0.28, 0.72), (0.6, 0.86)]
        let r = rect.width * 0.07
        for (x, y) in points {
            p.addEllipse(in: CGRect(x: rect.minX + rect.width * x - r, y: rect.minY + rect.height * y - r, width: r * 2, height: r * 2))
        }
        return p
    }
}

#Preview {
    HStack {
        ForEach([0, 0.3, 0.5, 0.8, 1], id: \.self) { ImoView(ripeness: $0, showsString: true) }
    }
}
