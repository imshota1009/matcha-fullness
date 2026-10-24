import DesignSystem
import SwiftUI

/// 集中する時間を、iOS 純正の時計アプリのタイマーのような「時間」と「分」のドラム(ホイール)で決める。
/// 0 時間 1 分 〜 9 時間 59 分(h:mm)。ドラムは iOS 標準の Picker(.wheel)なので、回すたびに iOS 標準の触覚が出る。
struct DurationDial: View {
    @Binding var minutes: Int

    var body: some View {
        let hours = Binding(get: { minutes / 60 }, set: { minutes = max(1, $0 * 60 + minutes % 60) })
        let mins = Binding(get: { minutes % 60 }, set: { minutes = max(1, (minutes / 60) * 60 + $0) })
        VStack(spacing: Theme.Spacing.s) {
            Text(String(format: "%d:%02d", minutes / 60, minutes % 60))
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Palette.text)
                .contentTransition(.numericText())
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                Picker("時間", selection: hours) {
                    ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                Text("時間").font(.headline).foregroundStyle(Theme.Palette.text)
                Picker("分", selection: mins) {
                    ForEach(0..<60, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                Text("分").font(.headline).foregroundStyle(Theme.Palette.text)
            }
            .frame(height: 200)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("集中する時間 \(minutes / 60)時間\(minutes % 60)分")
    }
}
