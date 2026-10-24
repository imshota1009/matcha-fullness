import Foundation

/// 点て方。オンボーディングで選び、設定で変えられる
enum WhiskMode: String, Codable, CaseIterable, Identifiable {
    /// スマホを手に持って振る・回す(センサー)
    case gyro
    /// スマホを机に置き、画面の茶碗の上で指を動かす
    case finger
    var id: Self { self }
    var title: String { self == .gyro ? "振って点てる" : "指で点てる" }
    var detail: String {
        self == .gyro
            ? "スマホを手に持ち、茶筅のように小さく振ったり、手首を回したりして点てます。"
            : "スマホを机に置いて画面を上に。上から見た茶碗の上で、指を前後に動かして点てます。"
    }
    var symbol: String { self == .gyro ? "iphone.radiowaves.left.and.right" : "hand.draw" }

    static let storageKey = "whiskMode"
}

/// 茶碗の種類(Unity で作った単色の茶碗)。設定で選べる。志野がアプリアイコンの茶碗
enum ChawanStyle: String, CaseIterable, Identifiable {
    case shino, kuroraku, oribe, nezumi
    var id: Self { self }
    var name: String {
        switch self {
        case .shino: "志野"
        case .kuroraku: "黒楽"
        case .oribe: "織部"
        case .nezumi: "鼠志野"
        }
    }
    var imageName: String { "Chawan_\(rawValue)" }

    static let storageKey = "chawan"
}

/// 一服1回の記録
struct Serving: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    /// 点前の褒め言葉
    var praise: String
    /// 今日の一事(掛け軸の言葉)
    var ichiji: String
    /// 点前の点数(0〜100)
    var score = 0
    /// この一服で増えた茶点
    var points = 0
    var mode = WhiskMode.gyro

    init(id: UUID = UUID(), date: Date, praise: String, ichiji: String, score: Int = 0, points: Int = 0, mode: WhiskMode = .gyro) {
        self.id = id; self.date = date; self.praise = praise; self.ichiji = ichiji
        self.score = score; self.points = points; self.mode = mode
    }

    // 古いデータ(点数なし)も読めるようにする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        praise = try c.decode(String.self, forKey: .praise)
        ichiji = try c.decode(String.self, forKey: .ichiji)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        mode = try c.decodeIfPresent(WhiskMode.self, forKey: .mode) ?? .gyro
    }
}

/// 段位。茶点が貯まるほど上がり、下がることはない
struct Rank {
    let name: String
    let threshold: Int

    static let all = [
        Rank(name: "入門", threshold: 0),
        Rank(name: "初伝", threshold: 300),
        Rank(name: "中伝", threshold: 1_000),
        Rank(name: "奥伝", threshold: 2_500),
        Rank(name: "皆伝", threshold: 5_000),
    ]

    static func current(for points: Int) -> Rank { all.last { points >= $0.threshold } ?? all[0] }
    static func next(for points: Int) -> Rank? { all.first { points < $0.threshold } }

    /// 次の段位までの進み具合(0〜1)
    static func progress(for points: Int) -> Double {
        guard let next = next(for: points) else { return 1 }
        let now = current(for: points)
        return Double(points - now.threshold) / Double(next.threshold - now.threshold)
    }
}

/// アプリ全体の記録。アプリとウィジェットで共有する。習慣づくりのため、記録は消さずに残す。
struct TeaRecord: Codable, Hashable {
    /// 挽き上がって、まだ点てていない抹茶(杯)
    var matchaCups = 0
    /// いま挽いている途中の分(0〜1)。持ち上げても消えない
    var grindProgress = 0.0
    /// これまで石臼を回した時間の合計(秒)。茶壺の「〇時間もの」に使う
    var groundSeconds = 0.0
    var servings: [Serving] = []
    /// 挽き上げた回数(集中をやり切った回数)
    var focusSessions = 0

    /// 集中1回をやり切ると増える茶点
    static let focusPoints = 30

    init(matchaCups: Int = 0, grindProgress: Double = 0, groundSeconds: Double = 0, servings: [Serving] = [], focusSessions: Int = 0) {
        self.matchaCups = matchaCups; self.grindProgress = grindProgress; self.groundSeconds = groundSeconds
        self.servings = servings; self.focusSessions = focusSessions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchaCups = try c.decodeIfPresent(Int.self, forKey: .matchaCups) ?? 0
        grindProgress = try c.decodeIfPresent(Double.self, forKey: .grindProgress) ?? 0
        groundSeconds = try c.decodeIfPresent(Double.self, forKey: .groundSeconds) ?? 0
        servings = try c.decodeIfPresent([Serving].self, forKey: .servings) ?? []
        focusSessions = try c.decodeIfPresent(Int.self, forKey: .focusSessions) ?? 0
    }

    func cupsToday(now: Date = .now) -> Int {
        servings.filter { Calendar.current.isDate($0.date, inSameDayAs: now) }.count
    }

    var latestIchiji: String? { servings.last?.ichiji }

    /// 茶点の合計(一服の点数 + 集中のぶん)。減ることはない
    var totalPoints: Int { servings.reduce(0) { $0 + $1.points } + focusSessions * Self.focusPoints }

    var bestScore: Int { servings.map(\.score).max() ?? 0 }

    /// 一服した日の集合(その日の 0 時)
    var servedDays: Set<Date> { Set(servings.map { Calendar.current.startOfDay(for: $0.date) }) }

    /// 今週(月曜はじまり)に一服した日数
    func daysThisWeek(now: Date = .now) -> Int {
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return servedDays.filter { week.contains($0) }.count
    }
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
