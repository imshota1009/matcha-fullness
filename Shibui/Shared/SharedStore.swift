import Foundation

/// アプリとウィジェットで共有する記録。App Group のコンテナに JSON ファイルで置く。
/// (シミュレーターでは App Group の UserDefaults が不安定なため、ファイルで共有する)
struct Record: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var note: String
    var date: Date
}

enum SharedStore {
    static let appGroup = "group.com.imshota1009.shibui"
    /// ウィジェットのタップでアプリを開く URL
    static let openURL = URL(string: "shibui://home")!

    private static var fileURL: URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return container.appendingPathComponent("entries.json")
    }

    static func load() -> [Record] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Record].self, from: data)) ?? []
    }

    static func save(_ entries: [Record]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
