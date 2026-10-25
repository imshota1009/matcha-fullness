import AVFoundation

/// 音(10/25 開発者の依頼で復活)。
/// - 茶筅: 往復ごとに「シャッ」(音量 1 の基準。コードで合成)
/// - 自然の音は3種類(川・風・鳥)。種類ごとに音量(0〜100%)を決められる。人によって好みが違うため
///   - 点てるとき(設定でオン/オフ): 茶筅の 0.5 くらいに抑え、ときどきししおどし
///   - タイマー中: ずっと流れ、5分ごとにししおどしが「カコン」
/// 出入りはフェードイン・フェードアウト。鳥は録音の途中から、ゆっくり大きくなりながら入る。
/// 録音の出典は App/Sounds/CREDITS.txt と tech-used.md。
@MainActor
final class SoundBank {
    static let shared = SoundBank()

    /// 設定のキー(UserDefaults)
    static let ambientOnKey = "ambientOn"
    /// 自然の音の種類
    enum Nature: String, CaseIterable, Identifiable {
        case river, wind, birds
        var id: Self { self }
        var name: String {
            switch self {
            case .river: "川"
            case .wind: "風"
            case .birds: "鳥"
            }
        }
        var symbol: String {
            switch self {
            case .river: "water.waves"
            case .wind: "wind"
            case .birds: "bird"
            }
        }
        var volumeKey: String { "volume_\(rawValue)" }
        /// 音量バーの初期値(にぎやかにならないよう控えめに)
        static let defaultVolume = 0.4
        /// その種類の音量(0〜1)。初期値は 0.6
        var volume: Float {
            Float(UserDefaults.standard.object(forKey: volumeKey) as? Double ?? Self.defaultVolume)
        }
    }

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

    /// 茶筅の音を 1 としたときの、自然の音の大きさ(点てるとき)
    private static let bedLevel: Float = 0.5
    /// いまの自然の音の全体の大きさ(点てるときは 0.5、タイマーは 1)
    private var level: Float = 1

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for node in chasenNodes {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        for (node, name, loop) in [(riverNode, "river", true), (windNode, "wind", true), (birdNode, "birds", true), (shishiNode, "shishiodoshi", false)] {
            let buf = loop ? Self.loadLoop(name) : Self.load(name)
            buffers[name] = buf
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: buf?.format ?? format)
            node.volume = 0
        }
        try? engine.start()
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

    // MARK: 襖

    private lazy var fusumaBuffer = makeFusuma()
    private let fusumaNode = AVAudioPlayerNode()
    private var fusumaReady = false

    /// 襖が開く音。木の敷居の上を、紙の戸がすーっと滑る音(コードで合成)
    func fusuma() {
        if !engine.isRunning { try? engine.start() }
        if !fusumaReady {
            engine.attach(fusumaNode)
            engine.connect(fusumaNode, to: engine.mainMixerNode, format: format)
            fusumaReady = true
        }
        fusumaNode.volume = 0.9
        fusumaNode.scheduleBuffer(fusumaBuffer, at: nil, options: .interrupts)
        fusumaNode.play()
    }

    /// 低めのざらつき(すべる音)を、ゆっくり立ち上げて消し、最後に戸当たりの小さな「とん」
    private func makeFusuma() -> AVAudioPCMBuffer {
        var brown = 0.0, low = 0.0, band = 0.0
        let length = 1.35
        return buffer(seconds: length) { t in
            brown = (brown + Double.random(in: -0.03...0.03)) * 0.997
            low += (brown - low) * 0.06
            band += (brown - band) * 0.35
            let slide = (band - low)                       // すべる音(中くらいの高さ)
            let x = min(1, t / 1.1)
            let env = t < 1.1 ? pow(sin(.pi * x), 1.4) * (0.75 + 0.25 * sin(t * 23)) : 0
            // 敷居の継ぎ目の小さな凸凹
            let bump = t < 1.1 && Int(t * 9) % 3 == 0 ? 1.15 : 1.0
            // 戸当たりの「とん」(低い短い音)
            let knockT = t - 1.12
            let knock = knockT > 0 ? exp(-knockT * 30) * sin(2 * .pi * 180 * knockT) * 0.35 : 0
            return slide * env * bump * 9 + knock
        }
    }

    // MARK: 背景の自然の音

    /// 自然の音(川・風・鳥)を流しはじめる。`shishiEvery` 秒ごとにししおどし。
    /// `forTimer` のときは大きめ、点てるときは茶筅の半分くらい
    func startAmbient(shishiEvery: Double, forTimer: Bool) {
        if !engine.isRunning { try? engine.start() }
        isAmbientPlaying = true
        // 全体を控えめに(騒がしくならないように)。タイマーでも 0.6、点てるときは茶筅の半分の 0.5 をさらに 0.6 倍
        level = (forTimer ? 1 : Self.bedLevel) * 0.6
        for (node, name) in [(riverNode, "river"), (windNode, "wind")] where !node.isPlaying {
            guard let buf = buffers[name] else { continue }
            node.volume = 0
            node.scheduleBuffer(buf, at: nil, options: .loops)
            node.play()
        }
        if !birdNode.isPlaying, let buf = buffers["birds"] {
            // 鳥は録音の途中から入る(いつも同じ鳴き声から始まらないように)
            birdNode.volume = 0
            let start = AVAudioFramePosition(Double.random(in: 0.2...0.7) * Double(buf.frameLength))
            if let rest = Self.slice(buf, from: start) { birdNode.scheduleBuffer(rest, at: nil) }
            birdNode.scheduleBuffer(buf, at: nil, options: .loops)
            birdNode.play()
        }
        applyVolume(fade: 2.5, birdsFade: 7)
        accents?.cancel()
        accents = Task { @MainActor [weak self] in
            var t = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                t += 1
                guard let self else { return }
                if shishiEvery.isFinite, t.truncatingRemainder(dividingBy: shishiEvery) == 0 { self.kakon() }
            }
        }
    }

    /// 自然の音を止める(フェードアウト)
    func stopAmbient() {
        isAmbientPlaying = false
        accents?.cancel()
        for node in [riverNode, windNode, birdNode, shishiNode] {
            fade(node, to: 0, seconds: 2.5) { node.stop() }
        }
    }

    /// 音量バーを動かしたとき(種類ごと)
    func applyVolume(fade seconds: Double = 0.15, birdsFade: Double? = nil) {
        guard isAmbientPlaying else { return }
        fade(riverNode, to: Nature.river.volume * level, seconds: seconds)
        fade(windNode, to: Nature.wind.volume * level * 0.6, seconds: seconds)
        // 鳥は 0 → 100 ではなく、なだらかに大きくなりはじめる(ゆっくりした曲線)
        fade(birdNode, to: Nature.birds.volume * level * 0.55, seconds: birdsFade ?? seconds, gentle: birdsFade != nil)
    }

    /// ししおどしの録音の中身(録音の音の大きさを 0.1 秒ごとに調べて求めた値)
    /// - 8.45 秒: 竹筒から水が流れ落ちはじめる
    /// - 10.40 秒: 竹筒が戻って「カコン」(録音の中でいちばん大きい音)
    static let pourOffset = 8.45, kakonOffset = 10.40
    /// 水が落ちはじめる手前から、音を少しずつ大きくする長さ(録音の秒)
    static let shishiLeadIn = 1.0
    /// 録音を速めたり遅くしたりする部品(音の高さは変えない)
    private let shishiSpeed = AVAudioUnitTimePitch()
    private var shishiSpeedReady = false

    /// ししおどしの音。画面で水が水たまりに届く瞬間に「水が落ちる音」、竹筒が戻る瞬間に「カコン」が鳴るよう、
    /// 録音の速さを rate 倍にして鳴らす(rate = 録音の「落ちはじめ→カコン」の長さ ÷ 画面の「水が届く→戻る」の長さ)。
    /// 呼ぶのは、水が届く時刻の shishiLeadIn / rate 秒前。その間に音を右上がりに大きくする
    func shishi(rate: Double) {
        guard let buf = buffers["shishiodoshi"] else { return }
        if !engine.isRunning { try? engine.start() }
        if !shishiSpeedReady {
            engine.disconnectNodeOutput(shishiNode)
            engine.attach(shishiSpeed)
            engine.connect(shishiNode, to: shishiSpeed, format: buf.format)
            engine.connect(shishiSpeed, to: engine.mainMixerNode, format: buf.format)
            shishiSpeedReady = true
        }
        let start = AVAudioFramePosition(max(0, Self.pourOffset - Self.shishiLeadIn) * buf.format.sampleRate)
        guard let seg = Self.slice(buf, from: start) else { return }
        shishiSpeed.rate = Float(min(3, max(0.5, rate)))
        shishiNode.stop()
        shishiNode.volume = 0
        shishiNode.scheduleBuffer(seg, at: nil, options: .interrupts)
        shishiNode.play()
        fade(shishiNode, to: 0.9 * level, seconds: Self.shishiLeadIn / Double(shishiSpeed.rate), gentle: true)
    }

    /// 点てるときの背景のししおどし(画面の動きはないので、ふつうの速さで鳴らす)
    func kakon() { shishi(rate: 1) }

    // MARK: 道具

    /// 音量をなめらかに変える。途中で別のフェードが来たら、そちらに引き継ぐ
    private func fade(_ node: AVAudioPlayerNode, to target: Float, seconds: Double, gentle: Bool = false, then done: (() -> Void)? = nil) {
        let key = ObjectIdentifier(node)
        fades[key]?.cancel()
        let start = node.volume
        fades[key] = Task { @MainActor in
            let steps = max(1, Int(seconds * 30))
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(33))
                if Task.isCancelled { return }
                let x = Float(i) / Float(steps)
                // ゆっくり始まり、ゆっくり終わる曲線。gentle のときは、はじめをさらにゆっくり(耳の感じ方に合わせて)
                let curve = gentle ? x * x * x : x * x * (3 - 2 * x)
                node.volume = start + (target - start) * curve
            }
            done?()
        }
    }

    /// 録音の途中から終わりまでを切り出す
    private static func slice(_ buf: AVAudioPCMBuffer, from start: AVAudioFramePosition) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(max(0, Int64(buf.frameLength) - start))
        guard count > 0, let out = AVAudioPCMBuffer(pcmFormat: buf.format, frameCapacity: count),
              let src = buf.floatChannelData, let dst = out.floatChannelData else { return nil }
        out.frameLength = count
        for ch in 0..<Int(buf.format.channelCount) {
            dst[ch].update(from: src[ch].advanced(by: Int(start)), count: Int(count))
        }
        return out
    }

    private static func load(_ name: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil else { return nil }
        return buf
    }

    /// 録音を読み、終わりと始まりを重ねてつなぎ目のないループにする(8秒の等パワークロスフェード)
    private static func loadLoop(_ name: String) -> AVAudioPCMBuffer? {
        guard let src = load(name), let data = src.floatChannelData else { return nil }
        let rate = src.format.sampleRate
        // 重ねる長さは 8 秒(録音が短いときは、その 4 分の 1)
        let total = Int(src.frameLength), x = min(Int(rate * 8), Int(src.frameLength) / 4)
        guard total > x * 2, let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(total - x)),
              let o = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(total - x)
        for ch in 0..<Int(src.format.channelCount) {
            for i in 0..<(total - x) {
                var v = data[ch][i]
                if i < x {
                    // 等パワーのクロスフェード(重なりの真ん中で音が小さくならない)
                    let t = Float(i) / Float(x) * .pi / 2
                    v = v * sin(t) + data[ch][total - x + i] * cos(t)
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
    /// 【10/25】やわらかい音にしたが、前の音のほうがよいとのことで戻した
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
