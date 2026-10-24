import Foundation

/// デモで空の茶室から始めないための初期データ。
enum MockData {
    static let record = TeaRecord(
        matchaCups: 0,
        grindProgress: 0,
        groundSeconds: 3 * 3600 + 20 * 60,
        servings: [
            Serving(date: .now.addingTimeInterval(-3 * 3600), praise: "結構なお点前で", ichiji: "英単語を三十"),
        ]
    )
}
