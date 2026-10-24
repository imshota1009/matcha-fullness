import ModelIO
import SceneKit
import SceneKit.ModelIO
import UIKit

/// 茶碗の種類ごとの色(3D モデル用)
extension ChawanStyle {
    var bodyColor: UIColor {
        switch self {
        case .shino: UIColor(red: 0.91, green: 0.87, blue: 0.80, alpha: 1)
        case .kuroraku: UIColor(red: 0.17, green: 0.12, blue: 0.09, alpha: 1)
        case .oribe: UIColor(red: 0.24, green: 0.36, blue: 0.24, alpha: 1)
        case .nezumi: UIColor(red: 0.55, green: 0.53, blue: 0.51, alpha: 1)
        }
    }
}

/// 点前の 3D の場面。茶碗・茶筅は Unity で作ったモデル(OBJ)を読み込み、抹茶の水面は波の計算で毎フレーム形を変える。
/// 見た目はフラット寄り: 色数を絞り、光はやわらかく一方向だけ。
final class TeaScene {
    let scene = SCNScene()
    let camera = SCNNode()
    /// 茶碗と抹茶をまとめたもの。「茶碗を回す」ときはこれを回す
    let bowlGroup = SCNNode()
    let chasen = SCNNode()
    private let chasenModel = SCNNode()
    private let bowl: SCNNode
    private let liquid = SCNNode()
    private let surface = FoamSurface()

    /// 水面の高さと半径(Unity の茶碗の寸法と同じ)
    static let liquidY: Float = 0.52
    static let liquidRadius: Float = 0.80

    init(style: ChawanStyle, withChasen: Bool = true) {
        bowl = Self.load("chawan", color: style.bodyColor)
        bowlGroup.addChildNode(bowl)
        liquid.geometry = surface.geometry
        let liquidNode = liquid
        surface.onGeometry = { liquidNode.geometry = $0 }
        liquid.position.y = Self.liquidY
        bowlGroup.addChildNode(liquid)
        scene.rootNode.addChildNode(bowlGroup)

        // 茶筅: 穂先を下に向け、穂先の位置を原点にする(原点 = 水面に触れる点)
        let bamboo = UIColor(red: 0.88, green: 0.76, blue: 0.54, alpha: 1)
        let bambooDark = UIColor(red: 0.74, green: 0.60, blue: 0.38, alpha: 1)
        for (name, color) in [("chasen_handle", bamboo), ("chasen_thread", UIColor(white: 0.1, alpha: 1)),
                              ("chasen_tines_outer", bamboo), ("chasen_tines_inner", bambooDark)] {
            chasenModel.addChildNode(Self.load(name, color: color))
        }
        chasenModel.eulerAngles.x = .pi
        chasenModel.position.y = 2.02
        chasenModel.scale = SCNVector3(0.5, 0.5, 0.5)
        chasenModel.position.y = 2.02 * 0.5
        chasen.addChildNode(chasenModel)
        chasen.position = SCNVector3(0, Self.liquidY + 0.9, 0)
        chasen.isHidden = !withChasen
        scene.rootNode.addChildNode(chasen)

        // 光: 上からのやわらかい光と、斜めからの弱い光だけ
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 720
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 420
        sun.eulerAngles = SCNVector3(-Float.pi / 2.6, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)

        // カメラ: 真上から(机に置いた iPhone を見下ろす視点)。茶碗が画面の高さいっぱいに入る
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 30
        camera.camera?.projectionDirection = .vertical
        camera.camera?.zNear = 0.1
        camera.position = SCNVector3(0, 4.75, 0)
        camera.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(camera)
        scene.background.contents = UIColor.clear
    }

    func setStyle(_ style: ChawanStyle) {
        bowl.enumerateHierarchy { n, _ in n.geometry?.firstMaterial?.diffuse.contents = style.bodyColor }
    }

    static func load(_ name: String, color: UIColor) -> SCNNode {
        let node = SCNNode()
        guard let url = Bundle.main.url(forResource: name, withExtension: "obj") else { return node }
        let asset = MDLAsset(url: url)
        let loaded = SCNScene(mdlAsset: asset)
        for child in loaded.rootNode.childNodes { node.addChildNode(child) }
        node.enumerateHierarchy { n, _ in
            guard let g = n.geometry else { return }
            let m = SCNMaterial()
            m.lightingModel = .lambert
            m.diffuse.contents = color
            m.isDoubleSided = true
            g.materials = [m]
        }
        return node
    }

    // MARK: - 毎フレーム

    func step(dt: Float, tip: SIMD2<Float>?, velocity: SIMD2<Float>, mode: FoamSurface.Mode) {
        surface.step(dt: dt, tip: tip, velocity: velocity, mode: mode)
    }

    var froth: Float { surface.froth }
    var coarseness: Float { surface.coarseness }

    /// 抹茶がすでに点った状態にする(プレビュー用)
    func prefill() { surface.prefill() }
}

/// 抹茶の水面。高さ(波)・泡の量・泡の粗さを格子で持ち、茶筅の動きでかき混ぜる。
/// 実際の薄茶の点て方に合わせている:
/// - はじめは抹茶の粉がダマになって浮いている。茶筅が通るとほぐれて溶ける
/// - すばやく前後(M の字)に振ると泡が立つ。はじめの泡は大きく粗い
/// - ゆっくり表面をなでると、大きな泡がつぶれてきめが細かくなる
/// - 最後の「の」の字で、泡が中央に集まってこんもりする
final class FoamSurface {
    enum Mode { case whisk, smooth, gather, idle }

    let geometry: SCNGeometry
    private let material = SCNMaterial()
    private static let n = 64          // 計算の格子
    private static let rings = 40, segments = 120
    private var h = [Float](repeating: 0, count: n * n)
    private var v = [Float](repeating: 0, count: n * n)
    private var foam = [Float](repeating: 0, count: n * n)
    private var powder = [Float](repeating: 0, count: n * n)
    private(set) var froth: Float = 0
    private(set) var coarseness: Float = 1
    private var bubbles: [Bubble] = []
    private var rng = SystemRandomNumberGenerator()
    private var frame = 0
    private var mound: Float = 0

    struct Bubble { var p: SIMD2<Float>; var r: Float; var life: Float }

    init() {
        // 粉のダマ(はじめの状態)
        var g = SystemRandomNumberGenerator()
        var lumps = [Float](repeating: 0, count: Self.n * Self.n)
        for _ in 0..<22 {
            let c = SIMD2<Float>(Float.random(in: -0.5...0.5, using: &g), Float.random(in: -0.5...0.5, using: &g))
            let r = Float.random(in: 0.02...0.06, using: &g)
            Self.splat(&lumps, at: c, radius: r, amount: 1)
        }
        powder = lumps
        let (src, idx) = Self.mesh(height: { _ in 0 })
        geometry = SCNGeometry(sources: src, elements: [idx])
        material.lightingModel = .lambert
        material.diffuse.contents = UIColor(red: 0.33, green: 0.50, blue: 0.20, alpha: 1)
        geometry.materials = [material]
        redrawTexture()
    }

    func prefill() {
        foam = foam.map { _ in 0.92 }
        powder = powder.map { _ in 0 }
        froth = 0.92
        coarseness = 0.1
        redrawTexture()
    }

    // MARK: 計算

    func step(dt: Float, tip: SIMD2<Float>?, velocity: SIMD2<Float>, mode: Mode) {
        let n = Self.n
        let speed = simd_length(velocity)
        if let tip, mode != .idle {
            // 茶筅の穂は輪のように水面に触れる。輪の上を押し下げて波を起こす
            // 穂の輪の上を押し下げ、内側を持ち上げる(水の量は変えない)
            let push = min(1.2, speed * 0.6) * dt * 60
            for k in 0..<10 {
                let a = Float(k) / 10 * 2 * .pi
                let q = tip + SIMD2(cos(a), sin(a)) * 0.06
                Self.splat(&v, at: q, radius: 0.035, amount: -0.0015 * push)
            }
            Self.splat(&v, at: tip, radius: 0.05, amount: 0.004 * push)
            // 粉はかき混ぜるとほぐれる
            Self.splat(&powder, at: tip, radius: 0.2, amount: -0.05 * (0.3 + speed))
            switch mode {
            case .whisk:
                let gen = min(1, speed * 0.55) * dt * 1.4
                Self.splat(&foam, at: tip, radius: 0.32, amount: gen)
                // 速いほど大きい泡ができる(はじめは粗い)
                coarseness = min(1, coarseness + gen * 0.08 * (froth < 0.6 ? 1 : 0.2))
                if speed > 0.8, coarseness > 0.35, Float.random(in: 0...1, using: &rng) < 0.2 { spawn(near: tip, big: true) }
            case .smooth:
                // 表面をなでると大きな泡がつぶれ、きめが細かくなる
                coarseness = max(0.05, coarseness - dt * 0.12 * (0.3 + speed))
                bubbles = bubbles.map { b in
                    var b = b
                    if b.r > 0.018, simd_distance(b.p, tip) < 0.18 { b.life = 0 }
                    return b
                }
                Self.splat(&foam, at: tip, radius: 0.25, amount: dt * 0.25)
            case .gather:
                mound = min(1, mound + dt * 0.25)
            case .idle: break
            }
        }
        // 波(減衰する波の式)
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                let lap = h[i - 1] + h[i + 1] + h[i - n] + h[i + n] - 4 * h[i]
                v[i] += lap * 0.35
                v[i] *= 0.965
            }
        }
        var mean: Float = 0
        for i in 0..<(n * n) { h[i] += v[i]; mean += h[i] }
        mean /= Float(n * n)
        // 平均の高さは 0 に保ち、波の高さにも上限をつける(水面が茶碗の底まで沈まないように)
        for i in 0..<(n * n) { h[i] = max(-0.035, min(0.035, (h[i] - mean) * 0.995)) }
        // 泡はゆっくりなじんで広がる
        blur(&foam, 0.22)
        var sum: Float = 0
        for i in 0..<(n * n) { foam[i] = min(1, foam[i]); powder[i] = max(0, powder[i]); sum += foam[i] }
        froth = min(1, sum / Float(n * n) / 0.78)
        // 泡の一生
        bubbles = bubbles.compactMap { b in
            var b = b
            b.life -= dt * (b.r > 0.018 ? 0.35 : 0.12)
            b.r *= (1 - dt * 0.05 * (1 - coarseness))
            return b.life > 0 ? b : nil
        }
        frame += 1
        updateMesh()
        if frame % 2 == 0 { redrawTexture() }
    }

    private func spawn(near p: SIMD2<Float>, big: Bool) {
        guard bubbles.count < 700 else { return }
        let a = Float.random(in: 0..<(2 * .pi), using: &rng)
        let d = Float.random(in: 0...0.2, using: &rng)
        let q = p + SIMD2(cos(a), sin(a)) * d
        guard simd_length(q) < TeaScene.liquidRadius - 0.03 else { return }
        let r = big ? Float.random(in: 0.012...0.03, using: &rng) * (0.4 + coarseness)
                    : Float.random(in: 0.004...0.012, using: &rng)
        bubbles.append(Bubble(p: q, r: r, life: Float.random(in: 0.6...1.4, using: &rng)))
    }

    /// 水面上の点(-R〜R)を格子の位置へ
    private static func cell(_ p: SIMD2<Float>) -> SIMD2<Float> {
        (p / TeaScene.liquidRadius * 0.5 + 0.5) * Float(n - 1)
    }

    private static func splat(_ f: inout [Float], at p: SIMD2<Float>, radius: Float, amount: Float) {
        let c = cell(p), r = radius / TeaScene.liquidRadius * 0.5 * Float(n - 1)
        let x0 = max(0, Int(c.x - r)), x1 = min(n - 1, Int(c.x + r) + 1)
        let y0 = max(0, Int(c.y - r)), y1 = min(n - 1, Int(c.y + r) + 1)
        guard x0 <= x1, y0 <= y1 else { return }
        for y in y0...y1 {
            for x in x0...x1 {
                let d = simd_distance(SIMD2(Float(x), Float(y)), c) / r
                if d < 1 { f[y * n + x] += amount * (1 - d * d) }
            }
        }
    }

    private func blur(_ f: inout [Float], _ k: Float) {
        let n = Self.n
        let src = f
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                f[i] = src[i] * (1 - k) + (src[i - 1] + src[i + 1] + src[i - n] + src[i + n]) * k / 4
            }
        }
    }

    private func sample(_ f: [Float], _ p: SIMD2<Float>) -> Float {
        let n = Self.n
        let c = Self.cell(p)
        let x = min(Float(n - 2), max(0, c.x)), y = min(Float(n - 2), max(0, c.y))
        let xi = Int(x), yi = Int(y), fx = x - Float(xi), fy = y - Float(yi)
        let a = f[yi * n + xi], b = f[yi * n + xi + 1], c2 = f[(yi + 1) * n + xi], d = f[(yi + 1) * n + xi + 1]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c2 * (1 - fx) + d * fx) * fy
    }

    // MARK: 形

    private static func mesh(height: (SIMD2<Float>) -> Float) -> ([SCNGeometrySource], SCNGeometryElement) {
        var verts: [SCNVector3] = [], uvs: [CGPoint] = [], idx: [UInt32] = []
        let R = TeaScene.liquidRadius
        verts.append(SCNVector3(0, height(.zero), 0)); uvs.append(CGPoint(x: 0.5, y: 0.5))
        for r in 1...rings {
            let rr = R * Float(r) / Float(rings)
            for s in 0..<segments {
                let a = Float(s) / Float(segments) * 2 * .pi
                let p = SIMD2(cos(a) * rr, sin(a) * rr)
                verts.append(SCNVector3(p.x, height(p), p.y))
                uvs.append(CGPoint(x: CGFloat(p.x / R * 0.5 + 0.5), y: CGFloat(p.y / R * 0.5 + 0.5)))
            }
        }
        for s in 0..<segments { idx += [0, UInt32(1 + (s + 1) % segments), UInt32(1 + s)] }
        for r in 1..<rings {
            let a0 = 1 + (r - 1) * segments, a1 = 1 + r * segments
            for s in 0..<segments {
                let s1 = (s + 1) % segments
                idx += [UInt32(a0 + s), UInt32(a0 + s1), UInt32(a1 + s), UInt32(a0 + s1), UInt32(a1 + s1), UInt32(a1 + s)]
            }
        }
        let normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: verts.count)
        return ([SCNGeometrySource(vertices: verts), SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: uvs)],
                SCNGeometryElement(indices: idx, primitiveType: .triangles))
    }

    private func updateMesh() {
        let R = TeaScene.liquidRadius
        let m = mound
        let heightAt: (SIMD2<Float>) -> Float = { p in
            let edge = 1 - simd_length(p) / R
            let wave = self.sample(self.h, p) * min(1, edge * 6)
            // 泡の分だけ少し盛り上がり、「の」の字のあとは中央がこんもりする
            let foamLift = self.sample(self.foam, p) * 0.025
            return wave + foamLift + m * 0.04 * max(0, 1 - simd_length(p) / (R * 0.8))
        }
        let (src, idx) = Self.mesh(height: heightAt)
        // 法線は高さの差から求める
        let e: Float = 0.02
        var normals: [SCNVector3] = []
        var p = SIMD2<Float>(0, 0)
        func nAt(_ p: SIMD2<Float>) -> SCNVector3 {
            let dx = heightAt(p + SIMD2(e, 0)) - heightAt(p - SIMD2(e, 0))
            let dz = heightAt(p + SIMD2(0, e)) - heightAt(p - SIMD2(0, e))
            let v = simd_normalize(SIMD3(-dx, 2 * e, -dz))
            return SCNVector3(v.x, v.y, v.z)
        }
        normals.append(nAt(p))
        for r in 1...Self.rings {
            let rr = R * Float(r) / Float(Self.rings)
            for s in 0..<Self.segments {
                let a = Float(s) / Float(Self.segments) * 2 * .pi
                p = SIMD2(cos(a) * rr, sin(a) * rr)
                normals.append(nAt(p))
            }
        }
        let g = SCNGeometry(sources: [src[0], SCNGeometrySource(normals: normals), src[2]], elements: [idx])
        g.materials = [material]
        // SCNGeometry は作り直して差し替える(ノードは TeaScene 側)
        onGeometry?(g)
    }

    var onGeometry: ((SCNGeometry) -> Void)?

    /// 細かい泡の点の位置(x, y は 0〜1、z はその点が出る泡の量のしきい値)
    private static let stipple: [SIMD3<Float>] = {
        var g = SystemRandomNumberGenerator()
        return (0..<12000).map { _ in SIMD3(Float.random(in: 0...1, using: &g), Float.random(in: 0...1, using: &g), Float.random(in: 0.05...0.95, using: &g)) }
    }()

    /// 水面の色(抹茶・泡・粉のダマ・泡粒)を絵にして貼る
    private func redrawTexture() {
        let size = 768
        let t = 128
        // 泡の量を色に: 濃い抹茶 → 明るい黄緑の泡
        let deep = SIMD3<Float>(0.30, 0.47, 0.18), light = SIMD3<Float>(0.70, 0.78, 0.42)
        let powderColor = SIMD3<Float>(0.20, 0.33, 0.12)
        var px = [UInt8](repeating: 255, count: t * t * 4)
        let R = TeaScene.liquidRadius
        for y in 0..<t {
            for x in 0..<t {
                let p = SIMD2((Float(x) / Float(t - 1) * 2 - 1) * R, (Float(y) / Float(t - 1) * 2 - 1) * R)
                let f = min(1, sample(foam, p) * 1.1)
                let pw = min(1, sample(powder, p))
                var c = deep + (light - deep) * f
                c = c + (powderColor - c) * pw * 0.9
                let i = (y * t + x) * 4
                px[i] = UInt8(c.x * 255); px[i + 1] = UInt8(c.y * 255); px[i + 2] = UInt8(c.z * 255)
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let small = CGContext(data: &px, width: t, height: t, bitsPerComponent: 8, bytesPerRow: t * 4, space: cs,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?.makeImage(),
              let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return }
        ctx.interpolationQuality = .high
        ctx.draw(small, in: CGRect(x: 0, y: 0, width: size, height: size))
        let scale = CGFloat(size) / CGFloat(2 * R)
        // きめの細かい泡(薄茶のクリーム状の泡): ごく小さな明暗の点を密に散らして、なめらかな質感にする。
        // 粗いうちは点が少し大きく、整えるほど細かくなる。光る輪や縁取りは使わない(炭酸のように見えるため)
        let dot = CGFloat(0.7 + 1.8 * coarseness)
        let lightDot = UIColor(red: 0.82, green: 0.87, blue: 0.58, alpha: 0.45).cgColor
        let darkDot = UIColor(red: 0.50, green: 0.62, blue: 0.27, alpha: 0.30).cgColor
        for (k, s) in Self.stipple.enumerated() {
            let p = SIMD2((s.x * 2 - 1) * R, (s.y * 2 - 1) * R)
            guard sample(foam, p) > s.z else { continue }
            let c = CGPoint(x: CGFloat(p.x + R) * scale, y: CGFloat(p.y + R) * scale)
            ctx.setFillColor(k % 3 == 0 ? darkDot : lightDot)
            ctx.fillEllipse(in: CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot))
        }
        // 点てはじめの大きな泡: 地の色より少し明るい丸で、ふちは目立たせない。整えると消える
        for b in bubbles {
            let c = CGPoint(x: CGFloat(b.p.x + R) * scale, y: CGFloat(b.p.y + R) * scale)
            let r = CGFloat(b.r) * scale
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            let alpha = CGFloat(min(1, b.life * 2))
            ctx.setFillColor(UIColor(red: 0.74, green: 0.81, blue: 0.48, alpha: 0.55 * alpha).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(UIColor(red: 0.58, green: 0.69, blue: 0.33, alpha: 0.5 * alpha).cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: rect)
        }
        material.diffuse.contents = ctx.makeImage()
    }
}

/// 茶碗のプレビュー。指でドラッグして、どの角度からでも見られる(SceneKit のカメラ操作)
import SwiftUI
import DesignSystem

struct ChawanPreviewSheet: View {
    let style: ChawanStyle
    let onChoose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tea: TeaScene = TeaScene(style: .shino, withChasen: false)

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.m) {
                SceneView(scene: tea.scene, pointOfView: tea.camera, options: [.allowsCameraControl])
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .background(TemaePalette.tatami, in: .rect(cornerRadius: Theme.Radius.m))
                    .accessibilityLabel("茶碗 \(style.name) の 3D プレビュー。ドラッグで回せます")
                Text("ドラッグで回す・ピンチで寄る")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
                PrimaryButton("この茶碗にする") {
                    onChoose()
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, Theme.Spacing.s)
            .navigationTitle(style.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseButton() }.sharedBackgroundVisibility(.hidden) }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            let t = TeaScene(style: style, withChasen: false)
            t.prefill()
            // 斜め上から見る。ゆっくり回して、形が分かるようにする
            t.camera.position = SCNVector3(0, 2.6, 3.4)
            t.camera.look(at: SCNVector3(0, 0.4, 0))
            t.camera.camera?.fieldOfView = 34
            t.scene.background.contents = UIColor(red: 0.65, green: 0.62, blue: 0.50, alpha: 1)
            t.bowlGroup.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 24)))
            tea = t
        }
    }
}
