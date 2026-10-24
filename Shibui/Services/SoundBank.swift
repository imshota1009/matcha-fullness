import AVFoundation

/// 茶室の音。音源ファイルを使わず、コードで波形を合成して鳴らす。
/// - 鹿威し: 竹が石を打つ「カコン」
/// - 茶筅: 振るたびに短い「シャッ」
/// - 松風: 釜の湯が沸く「ゴー」(呼吸に合わせて強弱をつける)
/// - 水琴窟: 挽き上がりの「キーン」
/// - 鳥のさえずり(録音、CC BY-SA 4.0。App/Sounds/CREDITS.txt): 点前と集中タイムの間に流す。出入りはフェードで
@MainActor
final class SoundBank {
    static let shared = SoundBank()

    private let engine = AVAudioEngine()
    private let oneShots = (0..<4).map { _ in AVAudioPlayerNode() }
    private var nextShot = 0
    private let matsukazeNode = AVAudioPlayerNode()
    /// 鳥のさえずり(自然の音)。点前と集中タイムの間、うしろで静かに流す
    private let ambientNode = AVAudioPlayerNode()
    private var ambientBuffer: AVAudioPCMBuffer?
    private var fades: [ObjectIdentifier: Task<Void, Never>] = [:]
    private static let ambientVolume: Float = 0.45
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private lazy var kakonBuffer = makeKakon()
    private lazy var chasenBuffer = makeChasen()
    private lazy var suikinkutsuBuffer = makeSuikinkutsu()
    private lazy var matsukazeBuffer = makeMatsukaze()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for node in oneShots + [matsukazeNode] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        ambientBuffer = Self.loadLoop("birds")
        engine.attach(ambientNode)
        engine.connect(ambientNode, to: engine.mainMixerNode, format: ambientBuffer?.format ?? format)
        ambientNode.volume = 0
        matsukazeNode.volume = 0
        try? engine.start()
    }

    func kakon() { play(kakonBuffer) }
    func chasen() { play(chasenBuffer, volume: 0.7) }
    func suikinkutsu() { play(suikinkutsuBuffer) }

    func startMatsukaze() {
        guard !matsukazeNode.isPlaying else { return }
        matsukazeNode.scheduleBuffer(matsukazeBuffer, at: nil, options: .loops)
        matsukazeNode.play()
    }

    /// 鳥のさえずりを、ゆっくり大きくして流しはじめる(フェードイン)
    func startAmbient(fade seconds: Double = 2.5) {
        guard let ambientBuffer else { return }
        if !engine.isRunning { try? engine.start() }
        if !ambientNode.isPlaying {
            ambientNode.volume = 0
            ambientNode.scheduleBuffer(ambientBuffer, at: nil, options: .loops)
            ambientNode.play()
        }
        fade(ambientNode, to: Self.ambientVolume, seconds: seconds)
    }

    /// 鳥のさえずりを、ゆっくり小さくして止める(フェードアウト)
    func stopAmbient(fade seconds: Double = 2.0) {
        fade(ambientNode, to: 0, seconds: seconds) { [weak self] in self?.ambientNode.stop() }
    }

    /// 音量をなめらかに変える。途中で別のフェードが来たら、そちらに引き継ぐ
    private func fade(_ node: AVAudioPlayerNode, to target: Float, seconds: Double, then done: (() -> Void)? = nil) {
        let key = ObjectIdentifier(node)
        fades[key]?.cancel()
        let start = node.volume
        fades[key] = Task { @MainActor in
            let steps = max(1, Int(seconds * 30))
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(33))
                if Task.isCancelled { return }
                let x = Float(i) / Float(steps)
                // ゆっくり始まり、ゆっくり終わる曲線
                node.volume = start + (target - start) * (x * x * (3 - 2 * x))
            }
            done?()
        }
    }

    /// 音源を読み、終わりと始まりを重ねてつなぎ目のないループにする(3秒のクロスフェード)
    private static func loadLoop(_ name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let src = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: src)) != nil, let data = src.floatChannelData else { return nil }
        let rate = file.processingFormat.sampleRate
        let total = Int(src.frameLength), x = Int(rate * 3)
        guard total > x * 2, let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(total - x)),
              let o = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(total - x)
        for ch in 0..<Int(src.format.channelCount) {
            for i in 0..<(total - x) {
                var v = data[ch][i]
                // 先頭の x フレームに、末尾の x フレームを重ねる
                if i < x {
                    let t = Float(i) / Float(x)
                    v = v * t + data[ch][total - x + i] * (1 - t)
                }
                o[ch][i] = v
            }
        }
        return out
    }

    /// 0(静か)〜1(強い)
    func setMatsukaze(_ level: Double) { matsukazeNode.volume = Float(0.08 + 0.6 * level) }

    func stopMatsukaze() {
        fade(matsukazeNode, to: 0, seconds: 1.2) { [weak self] in self?.matsukazeNode.stop() }
    }

    private func play(_ buffer: AVAudioPCMBuffer, volume: Float = 1) {
        if !engine.isRunning { try? engine.start() }
        let node = oneShots[nextShot]
        nextShot = (nextShot + 1) % oneShots.count
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
    }

    // MARK: - 合成

    private func buffer(seconds: Double, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(seconds * format.sampleRate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buf.frameLength = count
        let data = buf.floatChannelData![0]
        for i in 0..<Int(count) {
            data[i] = Float(max(-1, min(1, sample(Double(i) / format.sampleRate))))
        }
        return buf
    }

    /// 竹の打音を2回(カ・コン)
    private func makeKakon() -> AVAudioPCMBuffer {
        func knock(_ t: Double, freq: Double) -> Double {
            guard t >= 0 else { return 0 }
            let env = exp(-t * 38)
            return env * (0.7 * sin(2 * .pi * freq * t) + 0.3 * sin(2 * .pi * freq * 2.7 * t)) + exp(-t * 400) * Double.random(in: -0.4...0.4)
        }
        return buffer(seconds: 0.7) { t in knock(t, freq: 720) * 0.9 + knock(t - 0.12, freq: 520) }
    }

    /// 茶筅: 高めの帯域の短いノイズ
    private func makeChasen() -> AVAudioPCMBuffer {
        var last = 0.0
        return buffer(seconds: 0.09) { t in
            let white = Double.random(in: -1...1)
            let high = white - last   // 低い音を削って「シャッ」に近づける
            last = white
            let env = sin(.pi * min(1, t / 0.09))
            return high * env * 0.5
        }
    }

    /// 水琴窟: 高い澄んだ音が、少し遅れて響き返す
    private func makeSuikinkutsu() -> AVAudioPCMBuffer {
        func drop(_ t: Double, _ freq: Double) -> Double {
            guard t >= 0 else { return 0 }
            return exp(-t * 3.2) * (sin(2 * .pi * freq * t) + 0.35 * sin(2 * .pi * freq * 2.01 * t))
        }
        return buffer(seconds: 2.4) { t in
            0.45 * drop(t, 1568) + 0.3 * drop(t - 0.22, 2093) + 0.2 * drop(t - 0.5, 1760)
        }
    }

    /// 松風: 低くこもったノイズ(ループ用に端をなめらかにする)
    private func makeMatsukaze() -> AVAudioPCMBuffer {
        var brown = 0.0
        let length = 4.0
        return buffer(seconds: length) { t in
            brown = (brown + Double.random(in: -0.02...0.02)) * 0.995
            let edge = min(1, min(t, length - t) / 0.2)
            return brown * 6 * edge
        }
    }
}
