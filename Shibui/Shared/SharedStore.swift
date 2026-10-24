import Foundation

/// 軒下に吊るした「欲しい物」1つ。アプリとウィジェットで共有する。
struct Kaki: Codable, Identifiable, Hashable {
    /// 何を干すか。干し芋が基本で、干し柿も選べる
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case imo    // 干し芋
        case kaki   // 干し柿
        var id: Self { self }
        var label: String { self == .imo ? "干し芋" : "干し柿" }
    }

    enum Decision: String, Codable {
        case bought   // 買った
        case passed   // 見送った
    }

    var id = UUID()
    var name: String
    var price: Int
    var hungAt: Date
    /// 干す長さ(秒)。これが過ぎると熟す
    var dryingSeconds: TimeInterval
    var kind: Kind = .imo
    var decision: Decision?
    var decidedAt: Date?

    init(id: UUID = UUID(), name: String, price: Int, hungAt: Date, dryingSeconds: TimeInterval,
         kind: Kind = .imo, decision: Decision? = nil, decidedAt: Date? = nil) {
        self.id = id; self.name = name; self.price = price; self.hungAt = hungAt
        self.dryingSeconds = dryingSeconds; self.kind = kind; self.decision = decision; self.decidedAt = decidedAt
    }

    // 古いデータ(kind なし)も読めるようにする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Int.self, forKey: .price)
        hungAt = try c.decode(Date.self, forKey: .hungAt)
        dryingSeconds = try c.decode(TimeInterval.self, forKey: .dryingSeconds)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .imo
        decision = try c.decodeIfPresent(Decision.self, forKey: .decision)
        decidedAt = try c.decodeIfPresent(Date.self, forKey: .decidedAt)
    }

    var ripeAt: Date { hungAt.addingTimeInterval(dryingSeconds) }

    /// 0(吊るしたて) 〜 1(食べごろ)
    func ripeness(at now: Date = .now) -> Double {
        guard dryingSeconds > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(hungAt) / dryingSeconds))
    }

    func isRipe(at now: Date = .now) -> Bool { ripeness(at: now) >= 1 }
}

/// App Group のコンテナに JSON で保存する。
/// (シミュレーターでは App Group の UserDefaults が不安定なため、ファイルで共有する)
enum SharedStore {
    static let appGroup = "group.com.imshota1009.spajam2026.shibui"
    /// ウィジェットのタップでアプリを開く URL
    static let openURL = URL(string: "shibui://home")!

    private static var fileURL: URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return container.appendingPathComponent("hoshiimo.json")
    }

    static func load() -> [Kaki]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Kaki].self, from: data)
    }

    static func save(_ kakis: [Kaki]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(kakis) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 見送って浮いたお金の合計
    static func savedAmount(_ kakis: [Kaki]) -> Int {
        kakis.filter { $0.decision == .passed }.reduce(0) { $0 + $1.price }
    }
}

extension Int {
    /// ¥12,800 の形
    var yen: String { "¥" + formatted(.number.grouping(.automatic)) }
}
