import DesignSystem
import SwiftUI

/// 自然の音の3本の音量バー(川・風・鳥)。人によって好みが違うので、種類ごとに 0〜100% を決められる。
/// 設定とタイマー画面で同じものを使う。
struct NatureMixer: View {
    @AppStorage(SoundBank.Nature.river.volumeKey) private var river = SoundBank.Nature.defaultVolume
    @AppStorage(SoundBank.Nature.wind.volumeKey) private var wind = SoundBank.Nature.defaultVolume
    @AppStorage(SoundBank.Nature.birds.volumeKey) private var birds = SoundBank.Nature.defaultVolume

    var body: some View {
        VStack(spacing: 0) {
            row(.river, $river)
            row(.wind, $wind)
            row(.birds, $birds)
        }
    }

    private func row(_ n: SoundBank.Nature, _ value: Binding<Double>) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Label(n.name, systemImage: n.symbol)
                .labelStyle(.titleAndIcon)
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(width: 52, alignment: .leading)
            WhiteSlider(value: value, label: "\(n.name)の音量") { SoundBank.shared.applyVolume() }
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.dsCaption.monospacedDigit())
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
