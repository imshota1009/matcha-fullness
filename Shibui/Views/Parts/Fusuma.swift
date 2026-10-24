import DesignSystem
import SwiftUI

/// 襖(ふすま)が左右に開くモーション。点てる画面の茶碗が出てくる前に、茶室へ入る区切りとして差し込む。
/// 襖は生成りの紙に焦茶の縁、丸い引手。フラットな描き方(影・グラデーションなし)。
struct FusumaOpening: View {
    let onOpened: () -> Void
    @State private var open = false

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            HStack(spacing: 0) {
                panel(pullOnRight: true).frame(width: half).offset(x: open ? -half : 0)
                panel(pullOnRight: false).frame(width: half).offset(x: open ? half : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!open)
        .task {
            // 起動引数 `-fusumaHold 秒` で、閉じたまま待つ(画面確認用)
            let hold = UserDefaults.standard.double(forKey: "fusumaHold")
            try? await Task.sleep(for: .milliseconds(350 + Int(hold * 1000)))
            Haptics.selection()
            withAnimation(.timingCurve(0.45, 0, 0.25, 1, duration: 1.1)) { open = true }
            try? await Task.sleep(for: .milliseconds(1150))
            onOpened()
        }
        .accessibilityHidden(true)
    }

    private func panel(pullOnRight: Bool) -> some View {
        ZStack(alignment: pullOnRight ? .trailing : .leading) {
            Rectangle().fill(Color(red: 0.95, green: 0.93, blue: 0.87))
            // 紙の継ぎ目(うすい横線)
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in
                    Spacer()
                    Rectangle().fill(Theme.Palette.hai.opacity(0.18)).frame(height: 1)
                }
                Spacer()
            }
            // 焦茶の縁
            Rectangle().strokeBorder(Theme.Palette.kogecha, lineWidth: 10)
            // 丸い引手
            Circle()
                .strokeBorder(Theme.Palette.kogecha, lineWidth: 3)
                .background(Circle().fill(Theme.Palette.hai.opacity(0.35)))
                .frame(width: 30, height: 30)
                .padding(.horizontal, 26)
        }
    }
}
