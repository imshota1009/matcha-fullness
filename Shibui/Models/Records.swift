import Foundation
import SwiftData

/// 点てた記録(SPEC 8章)。「やめる」で中断した回は保存しない。
@Model
final class MatchaSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    /// 1日を5等分した時間帯(1〜5)
    var timeSlot: Int
    /// 所作スコア(集中の目安)
    var score: Int
    var foamScore: Int
    var lineScore: Int
    var rhythmScore: Int
    var countScore: Int
    var finishScore: Int
    var rotateScore: Int
    /// 泡の段階(0=粗い 〜 3=きめ細かい)
    var foamStage: Int
    var messageID: Int
    /// 操作モード。いまは常に「指」(将来の振るモードのために残す)
    var mode: String

    init(startedAt: Date, endedAt: Date = .now, score: Int, foamScore: Int = 0, lineScore: Int = 0, rhythmScore: Int = 0,
         countScore: Int = 0, finishScore: Int = 0, rotateScore: Int = 0, foamStage: Int = 0, messageID: Int = 0) {
        id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        timeSlot = TimeSlot.of(startedAt)
        self.score = score
        self.foamScore = foamScore
        self.lineScore = lineScore
        self.rhythmScore = rhythmScore
        self.countScore = countScore
        self.finishScore = finishScore
        self.rotateScore = rotateScore
        self.foamStage = foamStage
        self.messageID = messageID
        mode = "finger"
    }
}

/// 集中タイマーの記録(SPEC 8章)
@Model
final class FocusSession {
    var id: UUID
    var startedAt: Date
    /// 実際に終わった時刻(途中で終了したらその時刻)
    var endedAt: Date
    var plannedMinutes: Int
    var completed: Bool
    var matchaID: UUID?

    init(startedAt: Date, endedAt: Date, plannedMinutes: Int, completed: Bool, matchaID: UUID?) {
        id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.completed = completed
        self.matchaID = matchaID
    }
}

/// 1日を5等分した時間帯(① 0:00〜4:48 ② 4:48〜9:36 ③ 9:36〜14:24 ④ 14:24〜19:12 ⑤ 19:12〜24:00)
enum TimeSlot {
    static func of(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return min(5, minutes / 288 + 1)
    }
}

/// 泡の段階(SPEC 5章「泡スコアと泡の段階」)
enum FoamStage {
    static let names = ["粗い", "中", "細かい", "きめ細かい"]
    static func of(_ foamScore: Int) -> Int {
        switch foamScore {
        case 80...: 3
        case 60...: 2
        case 40...: 1
        default: 0
        }
    }
}

/// 茶碗の種類(Unity で作った茶碗)。設定で選べる。白(志野)がアプリアイコンの茶碗
enum ChawanStyle: String, CaseIterable, Identifiable {
    case shino, kuroraku, oribe, nezumi
    var id: Self { self }
    var name: String {
        switch self {
        case .shino: "白"
        case .kuroraku: "黒"
        case .oribe: "緑"
        case .nezumi: "灰色"
        }
    }
    var imageName: String { "Chawan_\(rawValue)" }

    static let storageKey = "chawan"
}

/// 前の試作(ファイル保存)の記録を、SwiftData へ一度だけ移す
enum LegacyImport {
    private struct OldRecord: Decodable { var servings: [OldServing]? }
    private struct OldServing: Decodable { var date: Date; var score: Int? }

    @MainActor
    static func run(into context: ModelContext) {
        let key = "importedLegacyRecords"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.imshota1009.spajam2026.shibui")
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let data = try? Data(contentsOf: container.appendingPathComponent("juubun.json")) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let old = try? decoder.decode(OldRecord.self, from: data) else { return }
        for s in old.servings ?? [] {
            context.insert(MatchaSession(startedAt: s.date, endedAt: s.date, score: s.score ?? 0))
        }
        try? context.save()
    }
}
