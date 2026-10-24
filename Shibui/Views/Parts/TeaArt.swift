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

/// 石臼。上の臼が回り、下に抹茶の粉が積もる。
struct IshiusuView: View {
    var angle: Double
    /// 積もった粉(0〜1)
    var powder: Double
    var size: CGFloat = 220

    var body: some View {
        VStack(spacing: size * 0.04) {
            ZStack {
                Circle().fill(Theme.Palette.hai)
                Circle().stroke(Theme.Palette.kogecha.opacity(0.35), lineWidth: 2).padding(size * 0.12)
                ForEach(0..<6) { i in
                    Rectangle()
                        .fill(Theme.Palette.kogecha.opacity(0.25))
                        .frame(width: 2, height: size * 0.36)
                        .offset(y: -size * 0.18)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                Circle().fill(Theme.Palette.kogecha).frame(width: size * 0.12)
                // 取っ手
                Capsule()
                    .fill(Theme.Palette.kogecha)
                    .frame(width: size * 0.08, height: size * 0.26)
                    .offset(x: size * 0.42)
            }
            .frame(width: size * 0.8, height: size * 0.8)
            .rotationEffect(.degrees(angle))

            // 積もった抹茶
            Capsule()
                .fill(Theme.Palette.matcha)
                .frame(width: size * (0.2 + 0.7 * powder), height: size * (0.03 + 0.1 * powder))
                .animation(.spring(duration: 0.5), value: powder)
        }
        .accessibilityHidden(true)
    }
}

/// 鹿威し。竹筒に水が溜まり、満杯で傾く。
struct ShishiOdoshiView: View {
    /// 0〜1
    var water: Double
    var tipped: Bool
    var size: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottom) {
            // 支柱
            Rectangle().fill(Theme.Palette.kogecha).frame(width: size * 0.06, height: size * 0.5).offset(x: -size * 0.1)
            Rectangle().fill(Theme.Palette.kogecha).frame(width: size * 0.06, height: size * 0.5).offset(x: size * 0.1)
            // 竹筒
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.matcha)
                Capsule()
                    .fill(Theme.Palette.shiro.opacity(0.7))
                    .frame(width: size * 0.9 * water)
                    .padding(size * 0.025)
            }
            .frame(width: size * 0.9, height: size * 0.16)
            .rotationEffect(.degrees(tipped ? 28 : -12 - 10 * water), anchor: .center)
            .offset(y: -size * 0.45)
            // 受けの石
            Ellipse().fill(Theme.Palette.hai).frame(width: size * 0.36, height: size * 0.14).offset(x: size * 0.42)
        }
        .frame(width: size, height: size * 0.75)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: tipped)
        .animation(.linear(duration: 0.2), value: water)
        .accessibilityElement()
        .accessibilityLabel(tipped ? "ししおどしが鳴りました" : "ししおどしに水がたまっています")
    }
}

/// 掛け軸。言葉を縦書きで見せる。
struct KakejikuView: View {
    var text: String
    var height: CGFloat = 320
    /// true のとき、上から掛け軸が下りてきて、下り終わってから文字が出る
    var unrolls = false
    @State private var unrolled = false
    @State private var textShown = false

    var body: some View {
        scroll
            .scaleEffect(x: 1, y: unrolls && !unrolled ? 0.04 : 1, anchor: .top)
            .opacity(unrolls && !unrolled ? 0 : 1)
            .task {
                guard unrolls else { textShown = true; return }
                withAnimation(.easeOut(duration: 0.9)) { unrolled = true }
                try? await Task.sleep(for: .seconds(0.95))
                textShown = true
            }
    }

    private var scroll: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.Palette.kogecha).frame(width: height * 0.42, height: height * 0.03)
            ZStack {
                Rectangle().fill(Theme.Palette.hai.opacity(0.35))
                Rectangle().fill(Theme.Palette.shiro).padding(.horizontal, height * 0.035).padding(.vertical, height * 0.06)
                VerticalText(text: text, fontSize: height * 0.085, brush: true, writing: unrolls, started: textShown)
                    .padding(.vertical, height * 0.1)
            }
            .frame(width: height * 0.36, height: height * 0.9)
            Capsule().fill(Theme.Palette.kogecha).frame(width: height * 0.42, height: height * 0.04)
        }
        .accessibilityElement()
        .accessibilityLabel("かけじく: \(text)")
    }
}

/// 日本語の縦書き(1文字ずつ縦に並べ、長ければ右から左へ列を折り返す)
struct VerticalText: View {
    var text: String
    var fontSize: CGFloat
    var perColumn = 10
    /// 筆文字(Yuji Syuku)で書く
    var brush = false
    /// true のとき、1文字ずつ筆で書いていくように上から現れる(started になってから)
    var writing = false
    var started = true

    var body: some View {
        let chars = Array(text)
        let columns = stride(from: 0, to: chars.count, by: perColumn).map { Array(chars[$0..<min($0 + perColumn, chars.count)]) }
        HStack(alignment: .top, spacing: fontSize * 0.4) {
            ForEach(Array(columns.enumerated().reversed()), id: \.offset) { _, column in
                VStack(spacing: fontSize * 0.08) {
                    ForEach(Array(column.enumerated()), id: \.offset) { i, ch in
                        let order = columns.prefix(while: { $0 != column }).reduce(0) { $0 + $1.count } + i
                        BrushChar(ch: ch, fontSize: fontSize, brush: brush,
                                  delay: writing ? Double(order) * 0.55 : nil, started: started)
                    }
                }
            }
        }
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

#Preview {
    VStack {
        ChawanView(foam: 0.8, size: 160)
        IshiusuView(angle: 20, powder: 0.5, size: 160)
        HStack { ShishiOdoshiView(water: 0.6, tipped: false); KakejikuView(text: "英単語を三十", height: 200) }
    }
}

/// 1文字。writing のときは、筆が上から下へ走るように墨が現れ、最後ににじみが引いて締まる
private struct BrushChar: View {
    let ch: Character
    let fontSize: CGFloat
    let brush: Bool
    /// nil なら最初から表示
    let delay: Double?
    let started: Bool
    @State private var drawn: CGFloat = 0
    @State private var settled = false

    var body: some View {
        Text(String(ch))
            .font(brush ? .custom("YujiSyuku-Regular", fixedSize: fontSize) : .system(size: fontSize, weight: .medium, design: .serif))
            .foregroundStyle(Theme.Palette.kogecha)
            .rotationEffect("ー〜…—「」（）".contains(ch) ? .degrees(90) : .zero)
            .blur(radius: delay == nil || settled ? 0 : 0.8)
            .mask(alignment: .top) {
                // 上から下へ、少し斜めに筆が進む
                Rectangle()
                    .frame(height: fontSize * 1.3 * (delay == nil ? 1 : drawn))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .onChange(of: started, initial: true) { _, go in
                guard go, let delay else { return }
                Task {
                    try? await Task.sleep(for: .seconds(delay))
                    withAnimation(.timingCurve(0.6, 0, 0.3, 1, duration: 0.5)) { drawn = 1 }
                    Haptics.selection()
                    try? await Task.sleep(for: .seconds(0.45))
                    withAnimation(.easeOut(duration: 0.3)) { settled = true }
                }
            }
    }
}
