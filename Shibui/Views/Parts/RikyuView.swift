import DesignSystem
import RiveRuntime
import SwiftUI

/// 案内役「りきゅうさん」。千利休をモデルにした、やさしいお茶の先生。
/// Rive で作ったアニメーション(App/rikyu.riv。Artboard `Rikyu`・State Machine `Main`)を再生する。
/// 作り直し方は app/rive/README-ja.md。
struct RikyuView: View {
    var size: CGFloat = 160
    /// 0=ふつう、1=うれしい、2=応援、3=集中
    var mood = 0
    var talking = false
    /// true になったときに、おじぎをする
    var bows = false
    /// true になったときに、手をふる
    var waves = false

    @State private var rive = RiveViewModel(fileName: "rikyu", stateMachineName: "Main", fit: .contain, artboardName: "Rikyu")

    var body: some View {
        rive.view()
            .frame(width: size, height: size)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("案内役のりきゅうさん")
            .onChange(of: mood, initial: true) { _, v in rive.setInput("mood", value: Double(v)) }
            .onChange(of: talking, initial: true) { _, v in rive.setInput("isTalking", value: v) }
            .onChange(of: bows, initial: true) { _, v in if v { rive.triggerInput("bow") } }
            .onChange(of: waves, initial: true) { _, v in if v { rive.triggerInput("wave") } }
    }
}

/// りきゅうさんのふきだし。文字が1文字ずつ出て、その間は口が動く
struct RikyuSays: View {
    let line: String
    var size: CGFloat = 96
    @State private var shown = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            RikyuView(size: size, talking: shown < line.count)
            Text(String(line.prefix(shown)))
                .font(.dsBody)
                .foregroundStyle(Theme.Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.l))
                .padding(.bottom, size * 0.35)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("りきゅうさん: \(line)")
        .task(id: line) {
            shown = 0
            for i in 1...max(1, line.count) {
                try? await Task.sleep(for: .milliseconds(45))
                shown = i
            }
        }
    }
}
