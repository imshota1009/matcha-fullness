import DesignSystem
import SwiftUI

/// 白いシンプルなスライダー(0〜1)。細い線と白い丸だけ。ガラスや影は使わない。
/// 明るい背景でも見えるよう、まだのところは灰の線、丸には薄い輪郭をつける。
struct WhiteSlider: View {
    @Binding var value: Double
    var label: String
    var onChange: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, knob: CGFloat = 26
            let x = CGFloat(value) * (w - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.hai.opacity(0.35)).frame(height: 4)
                Capsule().fill(Color.white).frame(width: x + knob / 2, height: 4)
                    .overlay(Capsule().stroke(Theme.Palette.hai.opacity(0.4), lineWidth: 0.5))
                Circle().fill(Color.white)
                    .overlay(Circle().stroke(Theme.Palette.hai.opacity(0.45), lineWidth: 1))
                    .frame(width: knob, height: knob)
                    .offset(x: x)
            }
            .frame(height: Theme.Size.minTouch)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                value = min(1, max(0, Double((g.location.x - knob / 2) / (w - knob))))
                onChange()
            })
        }
        .frame(height: Theme.Size.minTouch)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value * 100))%")
        .accessibilityAdjustableAction { dir in
            value = min(1, max(0, value + (dir == .increment ? 0.1 : -0.1)))
            onChange()
        }
    }
}
