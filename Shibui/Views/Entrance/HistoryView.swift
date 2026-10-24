import DesignSystem
import SwiftUI

/// 茶の記録(習慣づくり)。段位と茶点、点てた日の点々、数字のまとめ、これまでの一服。
/// Mobbin の Joi(点の並びと統計の一覧)と pillowtalk(今週と累計)を参考にした。
/// 連続記録は使わない(1日休んでも途切れず、何も減らない)。
struct HistoryView: View {
    @Environment(TeaStore.self) private var store

    var body: some View {
        NavigationStack {
            DSScreen("茶の記録") {
                let record = store.record
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Rank.current(for: record.totalPoints).name)
                            .font(.system(.largeTitle, design: .serif).weight(.bold))
                            .foregroundStyle(Theme.Palette.text)
                        Spacer()
                        Text("\(record.totalPoints) ポイント")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.Palette.matcha)
                    }
                    RankProgress(total: record.totalPoints)
                }
                .padding(.top, Theme.Spacing.l)

                SectionHeader("たてた日")
                DayDots(days: record.servedDays)
                    .padding(.top, Theme.Spacing.s)
                Text("休んだ日があっても、抹茶の入れものもランクも減りません。")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.top, Theme.Spacing.s)

                SectionHeader("まとめ")
                StatRow(label: "抹茶をたてた回数", value: "\(record.servings.count)杯")
                StatRow(label: "たてた日", value: "\(record.servedDays.count)日")
                StatRow(label: "今週", value: "\(record.daysThisWeek())日")
                StatRow(label: "スマホから離れて集中した時間", value: EntranceView.hours(record.groundSeconds))
                StatRow(label: "集中度の自己ベスト", value: "\(record.bestScore)")

                SectionHeader("これまでの記録")
                ForEach(record.servings.reversed()) { serving in
                    HStack(spacing: Theme.Spacing.m) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(serving.ichiji.isEmpty ? "(やることなし)" : serving.ichiji)
                                .font(.dsBody)
                                .foregroundStyle(Theme.Palette.text)
                            Text("\(serving.date.formatted(.dateTime.month().day().hour().minute())) ・ \(serving.praise)")
                                .font(.dsCaption)
                                .foregroundStyle(Theme.Palette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: serving.mode.symbol)
                            .font(.footnote)
                            .foregroundStyle(Theme.Palette.secondaryText)
                            .accessibilityLabel(serving.mode.title)
                        Text("集中度 \(serving.score)")
                            .font(.dsBody.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Theme.Palette.text)
                    }
                    .padding(.vertical, Theme.Spacing.m)
                    .accessibilityElement(children: .combine)
                    Rectangle().fill(Theme.Palette.separator).frame(height: 1)
                }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseButton() } }
        }
        .presentationDragIndicator(.visible)
    }
}

/// 直近5週ぶんの点々(月〜日)。点てた日は抹茶色で塗る
private struct DayDots: View {
    let days: Set<Date>
    private let weeks = 5

    var body: some View {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let first = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: weekStart) ?? weekStart
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        return VStack(spacing: Theme.Spacing.s) {
            HStack {
                ForEach(labels, id: \.self) { Text($0).font(.caption2).foregroundStyle(Theme.Palette.secondaryText).frame(maxWidth: .infinity) }
            }
            ForEach(0..<weeks, id: \.self) { w in
                HStack {
                    ForEach(0..<7, id: \.self) { d in
                        let date = cal.date(byAdding: .day, value: w * 7 + d, to: first) ?? first
                        let served = days.contains(date)
                        let future = date > today
                        Circle()
                            .fill(served ? Theme.Palette.matcha : Theme.Palette.separator.opacity(future ? 0.35 : 1))
                            .overlay { if cal.isDate(date, inSameDayAs: today) { Circle().stroke(Theme.Palette.text, lineWidth: 1.5).padding(-3) } }
                            .frame(width: 14, height: 14)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("この5週間で \(days.count) 日、抹茶をたてました")
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.dsBody).foregroundStyle(Theme.Palette.text)
            Spacer()
            Text(value).font(.dsBody.monospacedDigit()).foregroundStyle(Theme.Palette.secondaryText)
        }
        .padding(.vertical, Theme.Spacing.s)
        .frame(minHeight: Theme.Size.minTouch)
        .accessibilityElement(children: .combine)
    }
}

/// 設定。点て方・早送り・はじめの説明。
struct SettingsView: View {
    @Environment(TeaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WhiskMode.storageKey) private var mode = WhiskMode.gyro
    @AppStorage("didOnboard") private var didOnboard = true
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            DSScreen("設定") {
                SectionHeader("たて方")
                ModePicker(selection: $mode)
                    .padding(.top, Theme.Spacing.s)

                SectionHeader("茶碗")
                ChawanPicker(selection: $style)
                    .padding(.top, Theme.Spacing.s)

                SectionHeader("デモ")
                Toggle(isOn: $store.isFastMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("早送り").font(.dsBody).foregroundStyle(Theme.Palette.text)
                        Text("集中25分を10秒に縮めます").font(.dsCaption).foregroundStyle(Theme.Palette.secondaryText)
                    }
                }
                .tint(Theme.Palette.matcha)
                .frame(minHeight: Theme.Size.minTouch)
                .padding(.top, Theme.Spacing.s)
                Button {
                    dismiss()
                    openURL(URL(string: "shibui://sns")!)
                } label: {
                    Label("SNSを見ているところから試す", systemImage: "play")
                        .font(.dsBody)
                        .foregroundStyle(Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch, alignment: .leading)
                }

                SectionHeader("そのほか")
                Button {
                    dismiss()
                    didOnboard = false
                } label: {
                    Label("はじめの説明をもう一度見る", systemImage: "book")
                        .font(.dsBody)
                        .foregroundStyle(Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch, alignment: .leading)
                }
                Text("鳥のさえずり: \"Birdsong Bourne Woods 2020-04-27 0722\" by Robert EA Harvey (Wikimedia Commons, CC BY-SA 4.0)")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.top, Theme.Spacing.s)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseButton() } }
        }
        .presentationDragIndicator(.visible)
    }
}

/// 点て方を選ぶ2枚のカード。オンボーディングと設定で同じものを使う
struct ModePicker: View {
    @Binding var selection: WhiskMode

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(WhiskMode.allCases) { mode in
                Button {
                    Haptics.selection()
                    selection = mode
                } label: {
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        Image(systemName: mode.symbol)
                            .font(.title2)
                            .foregroundStyle(selection == mode ? Theme.Palette.matcha : Theme.Palette.secondaryText)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(mode.title).font(.headline).foregroundStyle(Theme.Palette.text)
                            Text(mode.detail).font(.dsCaption).foregroundStyle(Theme.Palette.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selection == mode ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selection == mode ? Theme.Palette.matcha : Theme.Palette.separator)
                    }
                    .padding(Theme.Spacing.m)
                    .background(selection == mode ? Theme.Palette.surface : .clear, in: .rect(cornerRadius: Theme.Radius.m))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                        .strokeBorder(selection == mode ? Theme.Palette.matcha : Theme.Palette.separator, lineWidth: selection == mode ? 1.5 : 1))
                    .contentShape(.rect)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
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
