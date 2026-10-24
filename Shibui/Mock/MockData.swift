import Foundation

/// デモで空の茶室から始めないための初期データ(数日ぶんの記録)。
enum MockData {
    private static let day: TimeInterval = 86_400

    static let record = TeaRecord(
        matchaCups: 0,
        grindProgress: 0,
        groundSeconds: 3 * 3600 + 20 * 60,
        servings: [
            Serving(date: .now.addingTimeInterval(-6 * day), praise: "心のこもった一杯です", ichiji: "レポートの序論", score: 64, points: 64),
            Serving(date: .now.addingTimeInterval(-5 * day), praise: "上手な一杯です", ichiji: "数学の演習を五問", score: 72, points: 122),
            Serving(date: .now.addingTimeInterval(-3 * day), praise: "上手な一杯です", ichiji: "単語帳を一周", score: 70, points: 70, mode: .finger),
            Serving(date: .now.addingTimeInterval(-1 * day), praise: "見事な一杯です", ichiji: "過去問を一年分", score: 91, points: 141),
            Serving(date: .now.addingTimeInterval(-3 * 3600), praise: "上手な一杯です", ichiji: "英単語を三十", score: 78, points: 78),
        ],
        focusSessions: 6
    )
}
