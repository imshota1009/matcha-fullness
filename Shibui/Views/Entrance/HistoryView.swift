import DesignSystem
import SwiftUI

/// 記録。今月のカレンダー(たてた日に印)、まとめ、これまでの一杯。
/// iOS 標準の List で作る。記録は左にスワイプで1つずつ、いちばん下のボタンでまとめて消せる。
struct HistoryView: View {
    @Environment(TeaStore.self) private var store
    @State private var confirmsDeleteAll = false

    var body: some View {
        let record = store.record
        NavigationStack {
            List {
                Section("今月の記録") {
                    MonthCalendar(days: record.servedDays)
                        .padding(.vertical, Theme.Spacing.s)
                }
                Section("まとめ") {
                    LabeledContent("抹茶をたてた回数", value: "\(record.servings.count)杯")
                    LabeledContent("たてた日", value: "\(record.servedDays.count)日")
                }
                Section {
                    ForEach(record.servings.reversed()) { serving in
                        HStack {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(serving.date.formatted(.dateTime.month().day().hour().minute()))
                                Text(serving.praise)
                                    .font(.dsCaption)
                                    .foregroundStyle(Theme.Palette.secondaryText)
                            }
                            Spacer()
                            Text("\(serving.score)")
                                .font(.title3.monospacedDigit().weight(.semibold))
                        }
                        .accessibilityElement(children: .combine)
                        .swipeActions {
                            Button("消す", systemImage: "trash", role: .destructive) {
                                withAnimation { store.deleteServing(serving.id) }
                            }
                        }
                    }
                } header: {
                    Text("これまでの一杯(集中の目安)")
                } footer: {
                    if !record.servings.isEmpty { Text("左にスワイプすると、1つずつ消せます") }
                }
                if !record.servings.isEmpty {
                    Section {
                        Button("記録をすべて消す", systemImage: "trash", role: .destructive) { confirmsDeleteAll = true }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background)
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
            .confirmationDialog("記録をすべて消しますか?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("すべて消す", role: .destructive) { withAnimation { store.deleteAll() } }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("これまでの記録がすべて消え、もとに戻せません。")
            }
        }
        .presentationDragIndicator(.visible)
    }
}

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

/// 設定。iOS 標準の Form で作る。茶碗・振動・はじめの説明。
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("didOnboard") private var didOnboard = true
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @AppStorage(Haptics.storageKey) private var hapticsOn = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ChawanPicker(selection: $style)
                        .padding(.vertical, Theme.Spacing.s)
                } header: {
                    Text("茶碗")
                } footer: {
                    Text("押すと 3D で見られます")
                }
                Section {
                    Toggle("振動", isOn: $hapticsOn)
                        .tint(Theme.Palette.matcha)
                }
                Section {
                    Button("はじめの説明をもう一度見る", systemImage: "book") {
                        dismiss()
                        didOnboard = false
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
                    .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationDragIndicator(.visible)
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
