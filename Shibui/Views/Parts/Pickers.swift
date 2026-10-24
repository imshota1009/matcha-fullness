import DesignSystem
import SwiftUI

/// 今月のカレンダー(月曜はじまり)。たてた日は抹茶色の丸と印、今日は輪で示す
struct MonthCalendar: View {
    let days: Set<Date>

    var body: some View {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        let month = cal.dateInterval(of: .month, for: today)!
        let count = cal.range(of: .day, in: .month, for: today)!.count
        // 1日の前に空けるマスの数(月曜=0)
        let lead = (cal.component(.weekday, from: month.start) + 5) % 7
        let cells: [Date?] = Array(repeating: nil, count: lead) + (0..<count).map { cal.date(byAdding: .day, value: $0, to: month.start) }
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        return VStack(spacing: Theme.Spacing.s) {
            Text(today.formatted(.dateTime.year().month()))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: Theme.Spacing.s) {
                ForEach(labels, id: \.self) { Text($0).font(.caption2).foregroundStyle(Theme.Palette.secondaryText) }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let done = days.contains(date)
                        ZStack {
                            Circle().fill(done ? Theme.Palette.matcha : .clear)
                            Text("\(cal.component(.day, from: date))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(done ? Theme.Palette.shiro : (date > today ? Theme.Palette.secondaryText : Theme.Palette.text))
                        }
                        .frame(width: 32, height: 32)
                        .overlay { if date == today { Circle().stroke(Theme.Palette.text, lineWidth: 1.5) } }
                        .accessibilityLabel("\(cal.component(.day, from: date))日\(done ? "、たてました" : "")")
                    } else {
                        Color.clear.frame(width: 32, height: 32)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// 茶碗の種類を選ぶ(横に並べた4つ)
struct ChawanPicker: View {
    @Binding var selection: ChawanStyle
    @State private var previewing: ChawanStyle?

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(ChawanStyle.allCases) { style in
                Button {
                    Haptics.selection()
                    previewing = style
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        ZStack {
                            Image(style.imageName).resizable().frame(width: 60, height: 60)
                            Circle().fill(Theme.Palette.matcha).frame(width: 60 * ChawanSpec.liquid / ChawanSpec.imageExtent)
                        }
                        Text(style.name)
                            .font(.dsCaption.weight(selection == style ? .semibold : .regular))
                            .foregroundStyle(Theme.Palette.text)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .background(selection == style ? Theme.Palette.surface : .clear, in: .rect(cornerRadius: Theme.Radius.m))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                        .strokeBorder(selection == style ? Theme.Palette.matcha : .clear, lineWidth: 1.5))
                    .contentShape(.rect)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("茶碗 \(style.name)。押すと 3D で見られます")
                .accessibilityAddTraits(selection == style ? .isSelected : [])
            }
        }
        // 起動引数 `-previewChawan oribe` などで開いた状態にできる(画面確認用)
        .task { previewing = UserDefaults.standard.string(forKey: "previewChawan").flatMap(ChawanStyle.init(rawValue:)) }
        .sheet(item: $previewing) { style in
            ChawanPreviewSheet(style: style) { selection = style }
        }
    }
}
