import DesignSystem
import SwiftUI

/// 集中する時間を、リングをなぞって決める(h:mm で表示)。
/// つまみを時計回りに1周させると 60 分。何周でもでき、1 分きざみで 1 分〜9 時間 59 分。
/// 1 分ごとに軽い触覚。リングを使わない人のために、−/+ ボタン(5 分ずつ)でも変えられる(代替経路)。
struct DurationDial: View {
    @Binding var minutes: Int
    private let step = 1, buttonStep = 5, minValue = 1, maxValue = 599
    @State private var lastAngle: Double?
    @State private var raw: Double = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let r = size / 2 - 22
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let within = Double(minutes % 60) / 60
                let a = within * 2 * .pi - .pi / 2
                ZStack {
                    Circle().stroke(Theme.Palette.ai.opacity(0.15), lineWidth: 18)
                        .frame(width: r * 2, height: r * 2)
                    // 1時間をこえた分は、いちど一周した輪で見せる
                    Circle()
                        .trim(from: 0, to: minutes >= 60 && minutes % 60 == 0 ? 1 : within)
                        .stroke(Theme.Palette.ai, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: r * 2, height: r * 2)
                    if minutes >= 60 {
                        Circle().stroke(Theme.Palette.ai.opacity(0.45), lineWidth: 18)
                            .frame(width: r * 2, height: r * 2)
                            .mask(Circle().trim(from: within, to: 1).stroke(lineWidth: 18).rotationEffect(.degrees(-90)).frame(width: r * 2, height: r * 2))
                    }
                    // つまみ
                    Circle().fill(Color.white)
                        .overlay(Circle().stroke(Theme.Palette.ai, lineWidth: 2))
                        .frame(width: 32, height: 32)
                        .position(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    VStack(spacing: 2) {
                        Text(String(format: "%d:%02d", minutes / 60, minutes % 60))
                            .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.Palette.text)
                            .contentTransition(.numericText())
                        Text("時間:分")
                            .font(.dsCaption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                    .position(c)
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let ang = atan2(g.location.y - c.y, g.location.x - c.x)
                        if let last = lastAngle {
                            var d = ang - last
                            if d > .pi { d -= 2 * .pi }
                            if d < -.pi { d += 2 * .pi }
                            raw = min(Double(maxValue), max(Double(minValue), raw + d / (2 * .pi) * 60))
                            set(Int((raw / Double(step)).rounded()) * step)
                        } else {
                            raw = Double(minutes)
                        }
                        lastAngle = ang
                    }
                    .onEnded { _ in lastAngle = nil })
            }
            .frame(height: 280)
            HStack(spacing: Theme.Spacing.xl) {
                FlatCircleButton(systemImage: "minus", label: "5分へらす") { set(minutes - buttonStep) }
                FlatCircleButton(systemImage: "plus", label: "5分ふやす") { set(minutes + buttonStep) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("集中する時間 \(minutes / 60)時間\(minutes % 60)分")
        .accessibilityAdjustableAction { dir in set(minutes + (dir == .increment ? buttonStep : -buttonStep)) }
    }

    private func set(_ v: Int) {
        let n = min(maxValue, max(minValue, v))
        guard n != minutes else { return }
        withAnimation(.snappy(duration: 0.15)) { minutes = n }
        Haptics.selection()
    }
}
