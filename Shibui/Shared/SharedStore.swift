import Foundation

/// 一服1回の記録
struct Serving: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    /// 点前の褒め言葉
    var praise: String
    /// 今日の一事(掛け軸の言葉)
    var ichiji: String
}

/// アプリ全体の記録。アプリとウィジェットで共有する。
struct TeaRecord: Codable, Hashable {
    /// 挽き上がって、まだ点てていない抹茶(杯)
    var matchaCups = 0
    /// いま挽いている途中の分(0〜1)。持ち上げても消えない
    var grindProgress = 0.0
    /// これまで石臼を回した時間の合計(秒)。茶壺の「〇時間もの」に使う
    var groundSeconds = 0.0
    var servings: [Serving] = []

    func cupsToday(now: Date = .now) -> Int {
        servings.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }.count
    }

    var latestIchiji: String? { servings.last?.ichiji }
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
        return container.appendingPathComponent("juubun.json")
    }

    static func load() -> TeaRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TeaRecord.self, from: data)
    }

    static func save(_ record: TeaRecord) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(record) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
