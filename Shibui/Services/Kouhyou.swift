import Foundation
import FoundationModels
import OSLog

/// 講評の切り分け用のログ(Xcode のコンソールと Mac の「コンソール」アプリにだけ出る。画面には出さない)
private let kouhyouLog = Logger(subsystem: "com.imshota1009.spajam2026.shibui", category: "Kouhyou")

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

    /// 端末内のモデル(SystemLanguageModel)の状態をログに出す
    static func logModelState() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            kouhyouLog.notice("availability: available")
        case .unavailable(let reason):
            kouhyouLog.notice("availability: unavailable reason=\(String(describing: reason), privacy: .public)")
        @unknown default:
            kouhyouLog.notice("availability: unknown")
        }
        kouhyouLog.notice("supportsLocale(ja_JP): \(model.supportsLocale(Locale(identifier: "ja_JP")), privacy: .public)")
        let langs = model.supportedLanguages.map { $0.maximalIdentifier }.sorted().joined(separator: ", ")
        kouhyouLog.notice("supportedLanguages: \(langs, privacy: .public)")
    }

    /// Foundation Models で講評を作る。使えない・失敗したときは nil(呼び出し側は定型文のまま)
    /// 使うのは端末内のモデル(SystemLanguageModel.default)。Private Cloud Compute のモデルは使わない
    static func generate(_ x: KouhyouInput) async -> Kouhyou? {
        logModelState()
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            kouhyouLog.notice("result: fallback (model unavailable)")
            return nil
        }
        let instructions = """
        The person's locale is ja_JP. 必ず日本語で答えること。
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
            let session = LanguageModelSession(model: model, instructions: instructions)
            let started = Date()
            // 20 秒で打ち切る(生成が止まったときに、原因をログに残すため)
            let content = try await withThrowingTaskGroup(of: Kouhyou?.self) { group in
                group.addTask { try await session.respond(to: prompt, generating: Kouhyou.self).content }
                group.addTask { try await Task.sleep(for: .seconds(20)); return nil }
                let first = try await group.next() ?? nil
                group.cancelAll()
                return first
            }
            guard let content else {
                kouhyouLog.notice("result: fallback (timeout 20s)")
                return nil
            }
            kouhyouLog.notice("result: AI in \(String(format: "%.1f", Date().timeIntervalSince(started)), privacy: .public)s review=\(content.review, privacy: .public)")
            return content
        } catch let error as LanguageModelSession.GenerationError {
            let kind: String
            switch error {
            case .unsupportedLanguageOrLocale: kind = "unsupportedLanguageOrLocale(言語・ロケール非対応)"
            case .guardrailViolation: kind = "guardrailViolation(ガードレール)"
            case .exceededContextWindowSize: kind = "exceededContextWindowSize(コンテキスト超過)"
            case .assetsUnavailable: kind = "assetsUnavailable(モデル準備中など)"
            case .decodingFailure: kind = "decodingFailure(型への変換に失敗)"
            case .rateLimited: kind = "rateLimited"
            case .concurrentRequests: kind = "concurrentRequests"
            case .refusal: kind = "refusal(回答を拒否)"
            case .unsupportedGuide: kind = "unsupportedGuide"
            @unknown default: kind = "unknown"
            }
            kouhyouLog.notice("result: fallback error=\(kind, privacy: .public) detail=\(String(describing: error), privacy: .public)")
            return nil
        } catch {
            kouhyouLog.notice("result: fallback error=other detail=\(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
