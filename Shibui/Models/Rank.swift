import Foundation

/// 成長していくランク(10/25 開発者の依頼)。裏千家の許状・資格の順番を参考にした名前。
/// 点てた一杯の所作スコアがそのまま「点」として積み重なり、下がることはない。
/// 参考: 裏千家ホームページ「許状・資格について」 https://www.urasenke.or.jp/home/textb/shiru/culic/
struct Rank: Equatable {
    let name: String
    /// 初級・中級・上級 などのまとまり
    let tier: String
    let threshold: Int

    static let all: [Rank] = [
        Rank(name: "入門", tier: "初級", threshold: 0),
        Rank(name: "小習", tier: "初級", threshold: 150),
        Rank(name: "茶箱点", tier: "初級", threshold: 350),
        Rank(name: "茶通箱", tier: "中級", threshold: 600),
        Rank(name: "唐物", tier: "中級", threshold: 900),
        Rank(name: "台天目", tier: "中級", threshold: 1_250),
        Rank(name: "盆点", tier: "中級", threshold: 1_650),
        Rank(name: "和巾点", tier: "中級", threshold: 2_100),
        Rank(name: "行之行台子", tier: "上級", threshold: 2_600),
        Rank(name: "大円草", tier: "上級", threshold: 3_200),
        Rank(name: "引次", tier: "上級", threshold: 3_900),
        Rank(name: "真之行台子", tier: "講師", threshold: 4_700),
        Rank(name: "大円真", tier: "講師", threshold: 5_600),
        Rank(name: "正引次", tier: "講師", threshold: 6_600),
        Rank(name: "茶名", tier: "専任講師", threshold: 7_700),
        Rank(name: "準教授", tier: "助教授", threshold: 9_000),
    ]

    static func current(for points: Int) -> Rank { all.last { points >= $0.threshold } ?? all[0] }
    static func next(for points: Int) -> Rank? { all.first { points < $0.threshold } }

    /// 次のランクまでの進み具合(0〜1)
    static func progress(for points: Int) -> Double {
        guard let next = next(for: points) else { return 1 }
        let now = current(for: points)
        return Double(points - now.threshold) / Double(next.threshold - now.threshold)
    }
}
