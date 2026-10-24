import Combine
import DesignSystem
import SwiftUI

/// F1 鹿威しの区切り。SNS風のダミー画面を見ている時間だけ竹筒に水が溜まり、満杯で「カコン」と鳴って茶室へ移る。
/// デモ用のため、約20秒で満杯になる。
struct SNSView: View {
    let go: (Stage) -> Void
    @State private var water = 0.0
    @State private var tipped = false
    private let fillSeconds = 20.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackToEntrance(go: go)
                Spacer()
                Text("タイムライン")
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Color.clear.frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
            }
            .padding(.horizontal, Theme.Spacing.s)

            ZStack(alignment: .topTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<40, id: \.self) { i in FakePost(index: i) }
                    }
                }
                ShishiOdoshiView(water: water, tipped: tipped, size: 96)
                    .padding(Theme.Spacing.s)
                    .background(Theme.Palette.background.opacity(0.92), in: .rect(cornerRadius: Theme.Radius.m))
                    .padding(Theme.Spacing.m)
            }
        }
        .background(Theme.Palette.background)
        .onReceive(timer) { _ in
            guard !tipped else { return }
            water = min(1, water + 0.1 / fillSeconds)
            if water >= 1 { kakon() }
        }
    }

    private func kakon() {
        tipped = true
        SoundBank.shared.kakon()
        Haptics.impact()
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            go(.ippuku)
        }
    }
}

/// ダミーの投稿。中身は灰色の帯で、文字や画像は出さない(実在のSNSに見せないため)。
private struct FakePost: View {
    let index: Int

    var body: some View {
        var rng = SeededRandom(seed: UInt64(index + 1))
        let lines = 1 + Int(rng.next() * 3)
        let hasImage = rng.next() > 0.5
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Circle().fill(Theme.Palette.separator).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(Theme.Palette.separator).frame(width: 90, height: 10)
                    Capsule().fill(Theme.Palette.separator.opacity(0.6)).frame(width: 60, height: 8)
                }
            }
            ForEach(0..<lines, id: \.self) { l in
                Capsule().fill(Theme.Palette.separator.opacity(0.8)).frame(maxWidth: l == lines - 1 ? 200 : .infinity).frame(height: 10)
            }
            if hasImage {
                RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.Palette.surface).frame(height: 180)
            }
        }
        .padding(Theme.Spacing.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.separator).frame(height: 1) }
        .accessibilityHidden(true)
    }
}
