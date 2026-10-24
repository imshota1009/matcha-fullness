import AVFoundation

/// 音(10/25 開発者の依頼で復活)。
/// - 茶筅の「シャカッ」: 点てる往復ごと(音量 1 の基準。コードで合成)
/// - 背景の自然の音(オプション): 川と風(茶筅の 0.5 くらい)がずっと流れ、ときどき鳥のさえずりとししおどし
/// - タイマー中: 自然の音がずっと流れ、5分ごとにししおどしが「カコン」
/// 背景の音量は設定とタイマー画面のスライダー(0〜100%)で決める。出入りはフェードイン・フェードアウト。
/// 録音の出典は App/Sounds/CREDITS.txt と tech-used.md。
@MainActor
final class SoundBank {
    static let shared = SoundBank()

    /// 設定のキー(UserDefaults)
    static let ambientOnKey = "ambientOn"
    static let ambientVolumeKey = "ambientVolume"

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let chasenNodes = (0..<3).map { _ in AVAudioPlayerNode() }
    private var nextChasen = 0
    private lazy var chasenBuffer = makeChasen()

    /// ずっと流れる音(川・風)と、ときどき鳴る音(鳥・ししおどし)
    private let riverNode = AVAudioPlayerNode()
    private let windNode = AVAudioPlayerNode()
    private let birdNode = AVAudioPlayerNode()
    private let shishiNode = AVAudioPlayerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var fades: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var accents: Task<Void, Never>?
    private(set) var isAmbientPlaying = false

    /// 茶筅の音を 1 としたときの、川と風の大きさ
    private static let bedLevel: Float = 0.5

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for node in chasenNodes {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        for (node, name, loop) in [(riverNode, "river", true), (windNode, "wind", true), (birdNode, "birds", false), (shishiNode, "shishiodoshi", false)] {
            let buf = loop ? Self.loadLoop(name) : Self.load(name)
            buffers[name] = buf
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: buf?.format ?? format)
            node.volume = 0
        }
        try? engine.start()
    }

    /// 設定のスライダーの値(0〜1)。初期値は 0.6
    static var ambientVolume: Float {
        UserDefaults.standard.object(forKey: ambientVolumeKey) as? Float ?? 0.6
    }

    // MARK: 茶筅

    func chasen() {
        if !engine.isRunning { try? engine.start() }
        let node = chasenNodes[nextChasen]
        nextChasen = (nextChasen + 1) % chasenNodes.count
        node.volume = 1
        node.scheduleBuffer(chasenBuffer, at: nil, options: .interrupts)
        node.play()
    }

    // MARK: 背景の自然の音

    /// 自然の音を流しはじめる(フェードイン)。`shishiEvery` 秒ごとにししおどし、鳥はときどき
    func startAmbient(shishiEvery: Double) {
        if !engine.isRunning { try? engine.start() }
        isAmbientPlaying = true
        for (node, name) in [(riverNode, "river"), (windNode, "wind")] where !node.isPlaying {
            guard let buf = buffers[name] else { continue }
            node.volume = 0
            node.scheduleBuffer(buf, at: nil, options: .loops)
            node.play()
        }
        applyVolume(fade: 2.5)
        accents?.cancel()
        accents = Task { @MainActor [weak self] in
            var nextShishi = shishiEvery
            var nextBird = Double.random(in: 8...18)
            var t = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                t += 1
                guard let self else { return }
                if t >= nextBird { self.playAccent(self.birdNode, "birds", level: 0.45); nextBird = t + Double.random(in: 25...45) }
                if t >= nextShishi { self.playAccent(self.shishiNode, "shishiodoshi", level: 0.7); nextShishi = t + shishiEvery }
            }
        }
    }

    /// 自然の音を止める(フェードアウト)
    func stopAmbient() {
        isAmbientPlaying = false
        accents?.cancel()
        for node in [riverNode, windNode, birdNode, shishiNode] {
            fade(node, to: 0, seconds: 2) { node.stop() }
        }
    }

    /// スライダーを動かしたとき
    func applyVolume(fade seconds: Double = 0.2) {
        guard isAmbientPlaying else { return }
        let v = Self.ambientVolume * Self.bedLevel
        fade(riverNode, to: v, seconds: seconds)
        fade(windNode, to: v * 0.8, seconds: seconds)
    }

    private func playAccent(_ node: AVAudioPlayerNode, _ name: String, level: Float) {
        guard let buf = buffers[name] else { return }
        node.stop()
        node.volume = 0
        node.scheduleBuffer(buf, at: nil, options: .interrupts)
        node.play()
        let v = Self.ambientVolume * level
        fade(node, to: v, seconds: 1.5)
        // 録音の終わりに向けて、静かに消す
        let length = Double(buf.frameLength) / buf.format.sampleRate
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(0, length - 2.5)))
            self?.fade(node, to: 0, seconds: 2.4)
        }
    }

    // MARK: 道具

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

    private static func load(_ name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil else { return nil }
        return buf
    }

    /// 録音を読み、終わりと始まりを重ねてつなぎ目のないループにする(3秒のクロスフェード)
    private static func loadLoop(_ name: String) -> AVAudioPCMBuffer? {
        guard let src = load(name), let data = src.floatChannelData else { return nil }
        let rate = src.format.sampleRate
        let total = Int(src.frameLength), x = Int(rate * 3)
        guard total > x * 2, let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(total - x)),
              let o = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(total - x)
        for ch in 0..<Int(src.format.channelCount) {
            for i in 0..<(total - x) {
                var v = data[ch][i]
                if i < x {
                    let t = Float(i) / Float(x)
                    v = v * t + data[ch][total - x + i] * (1 - t)
                }
                o[ch][i] = v
            }
        }
        return out
    }

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

    /// 茶筅の「シャッ」。高い音だけを残したノイズを、短く山なりに
    private func makeChasen() -> AVAudioPCMBuffer {
        var last = 0.0
        return buffer(seconds: 0.09) { t in
            let white = Double.random(in: -1...1)
            let high = white - last
            last = white
            let env = sin(.pi * min(1, t / 0.09))
            return high * env * 0.5
        }
    }
}
