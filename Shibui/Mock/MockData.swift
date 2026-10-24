import Foundation

/// デモで空の画面から始めないための初期データ。案が決まったら中身を差し替える。
enum MockData {
    static let entries: [Record] = [
        Record(title: "ゴーヤ", note: "苦かったが、最後まで食べた", date: .now.addingTimeInterval(-3600 * 26)),
        Record(title: "抹茶", note: "思ったより甘い", date: .now.addingTimeInterval(-3600 * 50)),
        Record(title: "ブラックコーヒー", note: "ひとくちだけ", date: .now.addingTimeInterval(-3600 * 75)),
    ]

    /// 「記録する」で追加する見本
    static let samples = ["ピーマン", "春菊", "緑茶", "みょうが", "ふきのとう"]
}
