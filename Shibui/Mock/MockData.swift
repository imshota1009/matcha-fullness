import Foundation

/// デモで空の軒下から始めないための初期データ。
enum MockData {
    private static let day: TimeInterval = 86_400

    static let kakis: [Kaki] = [
        Kaki(name: "ワイヤレスイヤホン", price: 24_800, hungAt: .now.addingTimeInterval(-7 * day), dryingSeconds: 7 * day),
        Kaki(name: "スニーカー", price: 15_400, hungAt: .now.addingTimeInterval(-4 * day), dryingSeconds: 7 * day, kind: .kaki),
        Kaki(name: "限定フィギュア", price: 8_800, hungAt: .now.addingTimeInterval(-2 * day), dryingSeconds: 30 * day),
        Kaki(name: "セールのコート", price: 12_000, hungAt: .now.addingTimeInterval(-12 * day), dryingSeconds: 7 * day,
             decision: .passed, decidedAt: .now.addingTimeInterval(-5 * day)),
        Kaki(name: "文庫本", price: 990, hungAt: .now.addingTimeInterval(-10 * day), dryingSeconds: 3 * day,
             decision: .bought, decidedAt: .now.addingTimeInterval(-7 * day)),
    ]
}
