import CoreHaptics
import DesignSystem
import Foundation

/// 茶筅の手触り(5章 J)。Core Haptics(CHHapticEngine)の連続した振動で作る。
/// - 指が触れている間は、振動を鳴らし続ける(連続イベント)
/// - 強さ(intensity)は指の速さに比例、鋭さ(sharpness)は泡が細かくなるほど上げる(「軽く細かい」手触り)
/// - 往復の折り返しの瞬間に、短いアクセント(一瞬のイベント)
/// 設定の「振動」がオフのときは鳴らさない。単発の合図(回すたびのカチッ等)は Haptics(簡易フィードバック)のまま。
@MainActor
final class WhiskHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var playing = false

    private var enabled: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
            && (UserDefaults.standard.object(forKey: Haptics.storageKey) as? Bool ?? true)
    }

    /// 点てる画面に入ったときに準備しておく(最初の振動が遅れないように)
    func prepare() {
        guard enabled, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.player = nil
                    self?.playing = false
                    try? self?.engine?.start()
                }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    /// 指が触れている間、毎フレーム呼ぶ。speed: 指の速さ(液面の座標/秒)、fineness: 泡の細かさ(0〜1)
    func update(touching: Bool, speed: Double, fineness: Double) {
        guard enabled, let engine else { return }
        if !touching {
            if playing { try? player?.stop(atTime: CHHapticTimeImmediate); playing = false }
            return
        }
        if !playing {
            do {
                // 長い連続イベントを1本鳴らし、強さと鋭さを動かしていく
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ], relativeTime: 0, duration: 60)
                let p = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: []))
                try p.start(atTime: CHHapticTimeImmediate)
                player = p
                playing = true
            } catch { return }
        }
        // 速さ 0〜2.5 を、強さ 0.08〜0.55 に(強すぎると疲れるので控えめ)
        let intensity = Float(0.08 + 0.47 * min(1, speed / 2.5))
        let sharpness = Float(0.25 + 0.6 * fineness)
        try? player?.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    /// 往復の折り返しの瞬間の、短いアクセント
    func accent(fineness: Double) {
        guard enabled, let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(0.4 + 0.5 * fineness)),
        ], relativeTime: 0)
        if let p = try? engine.makePlayer(with: CHHapticPattern(events: [event], parameters: [])) {
            try? p.start(atTime: CHHapticTimeImmediate)
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        playing = false
        engine?.stop()
        engine = nil
    }
}
