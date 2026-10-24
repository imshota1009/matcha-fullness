import SceneKit
import SwiftUI

/// ししおどしの 3D(Unity で作った部品)。竹筒の傾き・中の水位・かけいから落ちる水・傾いたときに落ちる水を動かす。
/// 背景は透明。水たまり(SwiftUI)の上に重ねる。
final class ShishiScene {
    let scene = SCNScene()
    let camera = SCNNode()
    private let pivot = SCNNode()
    private let water = SCNNode()
    private let drip = SCNNode()
    private let pour = SCNNode()
    private let dripSystem = SCNParticleSystem()
    private let pourSystem = SCNParticleSystem()

    /// 竹筒の角度(ラジアン)。受けるときは口が上、落とすときは口が下
    static let restAngle: Float = 0.42, pourAngle: Float = -0.62

    init() {
        let bamboo = UIColor(red: 0.60, green: 0.66, blue: 0.34, alpha: 1)
        let bambooDark = UIColor(red: 0.42, green: 0.47, blue: 0.22, alpha: 1)
        let wood = UIColor(red: 0.40, green: 0.30, blue: 0.21, alpha: 1)
        let waterColor = UIColor(red: 0.55, green: 0.70, blue: 0.84, alpha: 0.9)

        // 書き出した OBJ は x が左右反転しているので、親で戻す
        let root = SCNNode()
        root.scale = SCNVector3(-1, 1, 1)
        scene.rootNode.addChildNode(root)
        root.addChildNode(TeaScene.load("shishi_posts", color: wood))
        root.addChildNode(TeaScene.load("shishi_axle", color: wood))
        root.addChildNode(pivot)
        pivot.addChildNode(TeaScene.load("shishi_tube", color: bamboo))
        pivot.addChildNode(TeaScene.load("shishi_nodes", color: bambooDark))
        // 竹筒の中の水(節から口のほうへ溜まる)
        let w = TeaScene.load("shishi_water", color: waterColor)
        water.addChildNode(w)
        water.position = SCNVector3(-0.42, 0, 0)   // 反転しているので符号は逆
        water.scale = SCNVector3(0.01, 1, 1)
        pivot.addChildNode(water)
        pivot.eulerAngles.z = -Self.restAngle      // 反転しているので符号は逆

        // かけい: 口の上へ、右上から伸びる
        let kakei = TeaScene.load("shishi_kakei", color: bambooDark)
        let kakeiNode = SCNNode()
        kakeiNode.addChildNode(kakei)
        kakeiNode.eulerAngles.z = .pi - 0.25
        kakeiNode.position = SCNVector3(-(0.82 + 0.9 * cos(0.25)), 0.86 + 0.9 * sin(0.25), 0)
        root.addChildNode(kakeiNode)

        // かけいから落ちる細い水
        dripSystem.birthRate = 60
        dripSystem.particleLifeSpan = 0.5
        dripSystem.particleSize = 0.018
        dripSystem.particleColor = waterColor
        dripSystem.acceleration = SCNVector3(0, -4, 0)
        dripSystem.particleVelocity = 0.1
        dripSystem.emitterShape = SCNSphere(radius: 0.01)
        drip.addParticleSystem(dripSystem)
        drip.position = SCNVector3(0.82, 0.84, 0)
        scene.rootNode.addChildNode(drip)

        // 傾いたとき、口から水たまりへ落ちる水
        pourSystem.birthRate = 0
        pourSystem.particleLifeSpan = 0.9
        pourSystem.particleSize = 0.035
        pourSystem.particleColor = waterColor
        pourSystem.acceleration = SCNVector3(0, -5.5, 0)
        pourSystem.particleVelocity = 1.0
        pourSystem.particleVelocityVariation = 0.25
        pourSystem.spreadingAngle = 12
        pourSystem.emitterShape = SCNSphere(radius: 0.04)
        pour.addParticleSystem(pourSystem)
        scene.rootNode.addChildNode(pour)

        // 光と、少し上から見るカメラ
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 650
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional; sun.light?.intensity = 650
        sun.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(sun)
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 38
        camera.position = SCNVector3(0.35, 0.75, 5.6)
        camera.look(at: SCNVector3(0.35, -0.25, 0))
        scene.rootNode.addChildNode(camera)
        scene.background.contents = UIColor.clear
    }

    /// fill: 中の水位(0〜1)、tip: 傾き(0=受ける〜1=落とす)、pouring: 水が口から落ちている
    func update(fill: Double, tip: Double, pouring: Bool) {
        let angle = Self.restAngle + (Self.pourAngle - Self.restAngle) * Float(tip)
        pivot.eulerAngles.z = -angle
        water.scale.x = max(0.01, Float(fill) * 0.5)
        water.opacity = pouring ? CGFloat(max(0, 1 - tip)) : 1
        dripSystem.birthRate = pouring ? 0 : 60
        // 口の位置(竹筒の先)から、口の向きへ落とす
        let mouth = SCNVector3(cos(angle) * 0.92, sin(angle) * 0.92 + 0.05, 0)
        pour.position = mouth
        pourSystem.emittingDirection = SCNVector3(cos(angle) * 0.6, sin(angle), 0)
        pourSystem.birthRate = pouring && tip > 0.55 ? 220 : 0
    }
}

struct ShishiOdoshi3DView: UIViewRepresentable {
    let fill: Double
    let tip: Double
    let pouring: Bool

    func makeCoordinator() -> ShishiScene { ShishiScene() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.camera
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.update(fill: fill, tip: tip, pouring: pouring)
    }
}
