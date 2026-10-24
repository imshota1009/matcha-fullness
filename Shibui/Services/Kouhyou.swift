import Foundation
import FoundationModels

/// お点前の講評(5章 L-6)。採点の数値を、茶人が講評するような言葉にする。廃案の「AI の一言」(応援)とは別。
/// - Foundation Models(端末内の AI)で、講評・良かった点・次に意識すること を型どおりに受け取る(@Generable)
/// - 言葉づかい: 落ち着いた丁寧語。ほめるときは「渋い」を、よい意味(落ち着いた、味わいのある)で使う
/// - 数値をそのまま並べない。誇張や、医療的な効果をうたう表現はしない
/// - Apple Intelligence が使えない・失敗したときは、数値から決まる定型文を出す。結果画面は待たせない(講評はあとから出る)
@Generable(description: "お点前の講評")
struct Kouhyou {
    @Guide(description: "茶人の講評。1〜2文、60字以内、落ち着いた丁寧語。『渋い』を褒め言葉として自然に使う。数値は書かない")
    var review: String
    @Guide(description: "良かった点を1つ。30字以内。数値は書かない")
    var goodPoint: String
    @Guide(description: "次に意識することを1つ。30字以内。所作として具体的に(例: 奥と手前を、まっすぐに)。数値は書かない")
    var nextFocus: String
}

struct KouhyouInput {
    var meanSide: Double      // ē 横ブレの比率の平均(小さいほどまっすぐ)
    var cv: Double            // CV リズムのばらつき(小さいほど一定)
    var strokes: Int          // N 往復の数
    var foam: Int             // F 泡スコア
    var finish: Int           // S_finish 仕上げ
    var rotate: Int           // S_rotate 回す
    var total: Int            // P 所作スコア
    var previous: Int?        // 前回の P
}

enum KouhyouMaker {
    /// 数値から決まる定型文(AI が使えないときも、すぐ出す)
    static func fallback(_ x: KouhyouInput) -> Kouhyou {
        // 所作の要素ごとの出来(0〜1)
        let parts: [(String, Double, String, String)] = [
            ("line", 1 - min(1, x.meanSide / TemaeConstants.lineWorst), "奥と手前を、まっすぐに振れていました", "奥と手前を、まっすぐに"),
            ("rhythm", 1 - min(1, x.cv / TemaeConstants.rhythmWorst), "一定のリズムが、よく保たれていました", "力を抜いて、一定のリズムで"),
            ("count", min(1, Double(x.strokes) / Double(TemaeConstants.targetStrokes)), "最後まで手を止めずに点てられました", "もう少し長く、ていねいに点てて"),
            ("finish", Double(x.finish) / 100, "仕上げの「の」の字が、静かでした", "仕上げは、ゆっくり小さくくるりと"),
            ("rotate", Double(x.rotate) / 100, "茶碗の回し方が、ていねいでした", "茶碗は、九十度ずつ静かに回して"),
        ]
        let best = parts.max { $0.1 < $1.1 }!, worst = parts.min { $0.1 < $1.1 }!
        let review: String
        switch x.total {
        case 85...: review = "渋いお点前でした。所作に無駄がなく、落ち着きが感じられます。"
        case 65...: review = "渋い一服です。ところどころに、ていねいさが光っていました。"
        default: review = "味わいのある一服でした。回を重ねるほど、渋みが増していきます。"
        }
        return Kouhyou(review: review, goodPoint: best.2, nextFocus: worst.3)
    }

    /// Foundation Models で講評を作る。使えない・失敗したときは nil(呼び出し側は定型文のまま)
    static func generate(_ x: KouhyouInput) async -> Kouhyou? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let instructions = """
        あなたは茶道の先生です。生徒が抹茶を点てた所作を、短く講評します。
        落ち着いた丁寧語で話し、ほめるときは「渋い」を、落ち着いて味わいがあるという褒め言葉として自然に使います。
        数値をそのまま書かず、誇張や、健康・医療への効果をうたう表現はしません。
        """
        let prompt = """
        所作の測定結果(数値は書かないこと):
        - 横ブレの比率の平均 ē: \(String(format: "%.3f", x.meanSide))(0.05 以下でとてもまっすぐ、0.30 以上で大きくぶれている)
        - リズムのばらつき CV: \(String(format: "%.2f", x.cv))(0.10 以下でとても一定、0.60 以上でばらばら)
        - 往復の数 N: \(x.strokes)(目標 40)
        - 泡スコア F: \(x.foam) / 100
        - 仕上げ: \(x.finish) / 100、回す: \(x.rotate) / 100
        - 所作スコア P: \(x.total) / 100\(x.previous.map { "(前回は \($0))" } ?? "")
        講評・良かった点・次に意識することを書いてください。次に意識することは、いちばん弱い要素から具体的な所作の言葉で。
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: Kouhyou.self)
            return response.content
        } catch {
            return nil
        }
    }
}
