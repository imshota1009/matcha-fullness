import SwiftUI

/// 点てる画面の数値は、すべてここにまとめる(SPEC 5章「運用」)。
/// 実機で調整したら、変更前と変更後の値と理由を VERIFY.md に記録する。調整用のスライダー画面は作らない。
enum TemaeConstants {
    // MARK: 採点(SPEC 5章「採点の計算式」)

    /// 直線性: 横ブレの比率がこれ以下で100点、これ以上で0点
    static let lineBest = 0.05, lineWorst = 0.30
    /// リズム: ストローク時間の変動係数がこれ以下で100点、これ以上で0点
    static let rhythmBest = 0.10, rhythmWorst = 0.60
    /// 目標のストローク数
    static let targetStrokes = 40
    /// 点てている最中の泡の表示に使う、直近のストローク数
    static let liveWindow = 20
    /// 有効なストロークの長さ(茶碗の内側の半径を 1 とする。直径 2 の 35%)
    static let minStrokeLength = 0.7
    /// 泡スコアの重み
    static let weightLine = 0.45, weightRhythm = 0.35, weightCount = 0.20

    /// 仕上げ: 回転の合計の目標(度)、速さの係数が下がりはじめる速さ・仕上げとみなさない速さ(半径/秒)
    static let finishDegrees = 300.0
    static let finishSlow = 1.0, finishFast = 2.0

    /// 回す: 1回の目標角度・成立の許容幅・点数が 0 になる差(度)・静止の時間(秒)・回数
    static let rotateTarget = 45.0, rotateTolerance = 15.0, rotateZeroAt = 30.0
    static let rotateHold = 0.5, rotateTimes = 2
    /// 時計回りを正にするための符号(実機で確認する。VERIFY)
    static let clockwiseSign = -1.0

    /// 所作スコアの重み
    static let weightFoam = 0.70, weightFinish = 0.15, weightRotate = 0.15

    // MARK: 机置き判定

    /// 重力の z 成分がこれ以下(画面が上向き)
    static let deskGravityZ = -0.95
    /// 直近 0.5 秒のユーザー加速度の RMS がこれ以下(G)
    static let deskShakeRMS = 0.03
    static let deskWindow = 0.5

    // MARK: 泡と波(SPEC 5章「泡と波の表現」)

    /// シミュレーションの格子
    static let grid = 96
    /// 茶筅の太さ(茶碗の半径に対する割合)
    static let chasenRadius = 0.18
    /// 波の伝わりやすさと減衰(1フレームあたり)。指を止めて 1〜1.5 秒で収まる
    static let waveSpeed: Float = 0.30, waveDamping: Float = 0.955
    /// 泡の拡散(1フレームあたり)と、流れに運ばれる強さ
    static let foamDiffusion: Float = 0.30, foamAdvection: Float = 0.9
    /// 点てている間、泡が面全体へならされていく速さ(1秒あたり)。上手に点てれば 5〜8 秒で面全体をおおう
    static let foamMixing: Float = 0.22
    /// 泡が生まれる強さ
    static let foamBirth: Float = 0.03
    /// 点てている間、泡が泡スコアの上限まで細かくなっていく速さ(1秒あたり)
    static let foamRefine: Float = 0.30
    /// 振るのをやめたとき、大きい泡が消える速さ(1秒あたり)
    static let coarsePop: Float = 0.35

    /// 泡の段階ごとの泡の半径(テクスチャの画素。粗い / 中 / 細かい / きめ細かい)
    static let bubbleRadius: [CGFloat] = [7, 4.5, 2.6, 1.2]

    // MARK: 色(仮。デザイン担当が確定する)

    /// 点て始めの液(濃く暗い、透け感のある緑)
    static let liquidDark = SIMD3<Float>(0.20, 0.33, 0.12)
    /// 点て上がりの泡(淡く明るい、マットな抹茶色)
    static let foamLight = SIMD3<Float>(0.72, 0.79, 0.45)
    /// 抹茶の粒(濃い緑の小さな点)
    static let speck = UIColor(red: 0.27, green: 0.40, blue: 0.15, alpha: 0.75)
    /// 茶碗の内壁との境目の明るい輪
    static let rimLight = UIColor(red: 0.86, green: 0.90, blue: 0.66, alpha: 0.9)
}
