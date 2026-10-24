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
    private let surface = LiquidSurface()

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

    /// 水面を1フレーム進める
    func step(dt: Float, input: LiquidSurface.Input) {
        surface.step(dt: dt, input: input)
    }

    /// 往復の折り返し(液全体が奥⇔手前に揺れる)
    func slosh(direction: Float) { surface.slosh(direction: direction) }

    /// 指を離したときの中心のくぼみ(仕上げ)
    func dimple() { surface.dimple() }

    /// 液面の向き。回すときは、iPhone の回転を打ち消して空間に固定する
    func setLiquidRotation(_ radians: Float) { liquid.eulerAngles.y = radians }

    /// 抹茶がすでに点った状態にする(プレビュー用)
    func prefill() { surface.prefill() }
}

/// 抹茶の水面(SPEC 5章「泡と波の表現」)。シミュレーションと描画を分けている。
/// シミュレーション: 茶碗の内側を格子に区切り、マスごとに「液面の高さと速さ」「流れ」「泡の量」「泡の大きさ」を持つ。
/// 毎フレーム、波(減衰あり・縁で反射)、流れによる泡の移動と拡散、泡の生成・細分化・消滅を計算する。
/// 描画: 格子の値から、液の色・泡・明暗をテクスチャに描いて、波で起伏をつけた面に貼る。
final class LiquidSurface {
    struct Input {
        /// 茶筅の位置(液面の座標。半径 = TeaScene.liquidRadius)。触れていなければ nil
        var tip: SIMD2<Float>?
        /// 茶筅の速さ(液面の座標/秒)
        var velocity: SIMD2<Float> = .zero
        /// 点てている(泡が生まれる)
        var whisking = false
        /// 仕上げ中(通った所の大きな泡が消え、面がならされる)
        var smoothing = false
        /// いまの泡スコア(0〜100)。泡がどこまで細かくなれるかの上限を決める
        var foamScore: Double = 0
    }

    let geometry: SCNGeometry
    private let material = SCNMaterial()
    private static let n = TemaeConstants.grid
    private static let rings = 40, segments = 120

    private var h = [Float](repeating: 0, count: n * n)      // 液面の高さ
    private var hv = [Float](repeating: 0, count: n * n)     // 高さの速さ
    private var u = [Float](repeating: 0, count: n * n)      // 流れ(x)
    private var v = [Float](repeating: 0, count: n * n)      // 流れ(y)
    private var foam = [Float](repeating: 0, count: n * n)   // 泡の量(0〜1)
    private var size = [Float](repeating: 1, count: n * n)   // 泡の大きさ(1=粗い 〜 0=きめ細かい)
    private let inside: [Bool]
    private var frame = 0
    var onGeometry: ((SCNGeometry) -> Void)?


    init() {
        let n = Self.n
        inside = (0..<(n * n)).map { i in
            let x = Float(i % n) / Float(n - 1) * 2 - 1, y = Float(i / n) / Float(n - 1) * 2 - 1
            return x * x + y * y < 1
        }
        let (src, idx) = Self.mesh(height: { _ in 0 })
        geometry = SCNGeometry(sources: src, elements: [idx])
        material.lightingModel = .lambert
        geometry.materials = [material]
        setupShader()
        redraw()
    }

    func prefill() {
        foam = foam.map { _ in 0.95 }
        size = size.map { _ in 0.05 }
        redraw()
    }

    // MARK: 外からの出来事

    func slosh(direction: Float) {
        let n = Self.n
        for y in 0..<n {
            let yy = Float(y) / Float(n - 1) * 2 - 1
            for x in 0..<n where inside[y * n + x] { hv[y * n + x] += 0.004 * direction * yy }
        }
    }

    func dimple() {
        splat(&hv, at: .zero, radius: 0.12, amount: -0.012)
    }

    // MARK: 1フレーム

    func step(dt: Float, input: Input) {
        let n = Self.n, R = TeaScene.liquidRadius
        let speed = simd_length(input.velocity)
        // 泡が細かくなれる下限(泡スコアが高いほど細かくなれる)
        let finest = Float(1 - input.foamScore / 100) * 0.9 + 0.05

        if let tip = input.tip {
            let rc = Float(TemaeConstants.chasenRadius) * R
            let dir = speed > 0.001 ? input.velocity / speed : .zero
            forEachCell(near: tip, radius: rc) { i, rel, w in
                // 茶筅は液を押し流す。押した方向が盛り上がり、後ろがくぼむ
                u[i] += input.velocity.x * 0.08 * w
                v[i] += input.velocity.y * 0.08 * w
                // 茶筅の穂が液を外へ押し広げる
                let len = simd_length(rel)
                if len > 0.001 {
                    u[i] += rel.x / len * min(speed, 3) * 0.03 * w
                    v[i] += rel.y / len * min(speed, 3) * 0.03 * w
                }
                let front = simd_dot(rel, dir) / rc
                hv[i] += 0.0035 * min(speed, 3) * front * w
                if input.whisking {
                    // 大きく速いほど、泡が生まれる。生まれたばかりの泡は大きい
                    let born = TemaeConstants.foamBirth * min(speed, 3) * w
                    let before = foam[i]
                    foam[i] = min(1, foam[i] + born)
                    let added = foam[i] - before
                    if foam[i] > 0 { size[i] = (size[i] * before + 1.0 * added) / foam[i] }
                    // 通った所は、泡スコアの上限まで細かくなる
                    size[i] = max(finest, size[i] - 0.010 * min(speed, 3) * w)
                }
                if input.smoothing {
                    // 仕上げ: 大きな泡が消え、面がならされる
                    size[i] = max(finest, size[i] - 0.05 * w)
                    hv[i] *= 0.8
                }
            }
        }

        // 波(減衰あり)。茶碗の外は「となりと同じ高さ」として扱い、縁で反射させる
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                guard inside[i] else { continue }
                let c = h[i]
                let l = inside[i - 1] ? h[i - 1] : c, r = inside[i + 1] ? h[i + 1] : c
                let t = inside[i - n] ? h[i - n] : c, b = inside[i + n] ? h[i + n] : c
                hv[i] += (l + r + t + b - 4 * c) * TemaeConstants.waveSpeed
                hv[i] *= TemaeConstants.waveDamping
            }
        }
        var mean: Float = 0, count: Float = 0
        for i in 0..<(n * n) where inside[i] { h[i] += hv[i]; mean += h[i]; count += 1 }
        mean /= max(1, count)
        for i in 0..<(n * n) where inside[i] { h[i] = max(-0.04, min(0.04, h[i] - mean)) }

        // 流れは少しずつ弱まり、泡は流れに運ばれて広がる
        for i in 0..<(n * n) { u[i] *= 0.9; v[i] *= 0.9 }
        advect(&foam, dt: dt)
        advect(&size, dt: dt)
        blur(&foam, TemaeConstants.foamDiffusion)
        blur(&foam, TemaeConstants.foamDiffusion)
        blur(&size, TemaeConstants.foamDiffusion * 0.5)
        // 点てている間は、泡が面全体へならされていく(茶碗の中を液が大きくめぐるため)
        if input.whisking {
            var sumF: Float = 0, sumS: Float = 0, cnt: Float = 0
            for i in 0..<(n * n) where inside[i] { sumF += foam[i]; sumS += size[i] * foam[i]; cnt += 1 }
            let meanF = sumF / max(1, cnt), meanS = sumF > 0 ? sumS / sumF : 1
            let k = TemaeConstants.foamMixing * dt
            // 泡スコアが高いほど、面全体の泡が細かくなっていく
            let r = TemaeConstants.foamRefine * dt * Float(input.foamScore / 100)
            for i in 0..<(n * n) where inside[i] {
                foam[i] += (meanF - foam[i]) * k
                size[i] += (meanS - size[i]) * k
                size[i] = max(finest, size[i] - r)
            }
        }

        // 振るのをやめると、大きい泡からはじけて消える。きめ細かい泡は残る
        if !input.whisking {
            for i in 0..<(n * n) where size[i] > 0.45 {
                foam[i] = max(0, foam[i] - TemaeConstants.coarsePop * dt * (size[i] - 0.4))
            }
        }
        for i in 0..<(n * n) where !inside[i] { foam[i] = 0 }

        frame += 1
        updateMesh()
        redraw()  // 96×96 の値を渡すだけなので毎フレームでよい
    }

    // MARK: 格子の道具

    private func cell(_ p: SIMD2<Float>) -> SIMD2<Float> {
        (p / TeaScene.liquidRadius * 0.5 + 0.5) * Float(Self.n - 1)
    }

    private func forEachCell(near p: SIMD2<Float>, radius: Float, _ body: (Int, SIMD2<Float>, Float) -> Void) {
        let n = Self.n, c = cell(p), rr = radius / TeaScene.liquidRadius * 0.5 * Float(n - 1)
        let x0 = max(0, Int(c.x - rr)), x1 = min(n - 1, Int(c.x + rr) + 1)
        let y0 = max(0, Int(c.y - rr)), y1 = min(n - 1, Int(c.y + rr) + 1)
        guard x0 <= x1, y0 <= y1 else { return }
        let scale = TeaScene.liquidRadius * 2 / Float(n - 1)
        for y in y0...y1 {
            for x in x0...x1 {
                let i = y * n + x
                guard inside[i] else { continue }
                let rel = (SIMD2(Float(x), Float(y)) - c) * scale
                let d = simd_length(rel) / radius
                if d < 1 { body(i, rel, 1 - d * d) }
            }
        }
    }

    private func splat(_ f: inout [Float], at p: SIMD2<Float>, radius: Float, amount: Float) {
        var copy = f
        forEachCell(near: p, radius: radius) { i, _, w in copy[i] += amount * w }
        f = copy
    }

    private func sample(_ f: [Float], _ c: SIMD2<Float>) -> Float {
        let n = Self.n
        let x = min(Float(n - 2), max(0, c.x)), y = min(Float(n - 2), max(0, c.y))
        let xi = Int(x), yi = Int(y), fx = x - Float(xi), fy = y - Float(yi)
        let a = f[yi * n + xi], b = f[yi * n + xi + 1], c2 = f[(yi + 1) * n + xi], d = f[(yi + 1) * n + xi + 1]
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c2 * (1 - fx) + d * fx) * fy
    }

    /// 流れに乗せて運ぶ(1つ前の位置から値を持ってくる)
    private func advect(_ f: inout [Float], dt: Float) {
        let n = Self.n, src = f
        let k = TemaeConstants.foamAdvection * dt * Float(n - 1) / (TeaScene.liquidRadius * 2)
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                guard inside[i], u[i] != 0 || v[i] != 0 else { continue }
                f[i] = sample(src, SIMD2(Float(x) - u[i] * k, Float(y) - v[i] * k))
            }
        }
    }

    private func blur(_ f: inout [Float], _ k: Float) {
        let n = Self.n, src = f
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let i = y * n + x
                guard inside[i] else { continue }
                f[i] = src[i] * (1 - k) + (src[i - 1] + src[i + 1] + src[i - n] + src[i + n]) * k / 4
            }
        }
    }

    private func value(_ f: [Float], at p: SIMD2<Float>) -> Float { sample(f, cell(p)) }

    // MARK: 形(波で起伏をつけた面)

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
        let heightAt: (SIMD2<Float>) -> Float = { p in
            let edge = 1 - simd_length(p) / R
            return self.value(self.h, at: p) * min(1, edge * 6) + self.value(self.foam, at: p) * 0.02
        }
        let (src, idx) = Self.mesh(height: heightAt)
        let g = SCNGeometry(sources: src, elements: [idx])
        g.materials = [material]
        onGeometry?(g)
    }

    // MARK: 描画(GPU)

    /// シミュレーションの値(泡の量・泡の大きさ・液面の高さ)を、96×96 の小さなテクスチャにして GPU へ渡す。
    /// 色・泡・抹茶の粒・明暗・縁の輪は、GPU のシェーダー(LiquidShader)が1画素ずつ描く。
    /// 前は CPU で 640×640 の絵に泡を最大1万4千個描いていて、1回 12〜37ms かかり、茶筅が遅れる原因になっていた。
    private let simTexture = SCNMaterialProperty()
    private var simBytes = [UInt8](repeating: 0, count: n * n * 4)

    private func redraw() {
        let n = Self.n
        var sum: Float = 0
        for i in 0..<(n * n) {
            let f = min(1, max(0, foam[i])), sz = min(1, max(0, size[i]))
            simBytes[i * 4] = UInt8(f * 255)
            simBytes[i * 4 + 1] = UInt8(sz * 255)
            simBytes[i * 4 + 2] = UInt8(min(1, max(0, h[i] / 0.08 + 0.5)) * 255)
            simBytes[i * 4 + 3] = inside[i] ? 255 : 0
            sum += f
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let image = simBytes.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4, space: cs,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        simTexture.contents = image
        material.setValue(NSNumber(value: min(1, sum / Float(n * n) * 2)), forKey: "foamAvg")
    }

    /// 液面のマテリアルに、GPU で描くシェーダーをつける
    private func setupShader() {
        simTexture.minificationFilter = .linear
        simTexture.magnificationFilter = .linear
        simTexture.wrapS = .clamp
        simTexture.wrapT = .clamp
        material.setValue(simTexture, forKey: "simTex")
        material.setValue(NSNumber(value: Float(0)), forKey: "foamAvg")
        // diffuseTexcoord を使うため、白い 1 画素の画像を貼っておく(色だけだと座標が渡らない)
        material.diffuse.contents = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        material.shaderModifiers = [.surface: LiquidShader.surface]
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
