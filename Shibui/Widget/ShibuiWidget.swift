import DesignSystem
import SwiftUI
import WidgetKit

/// ホーム画面ウィジェット。今日取り戻した杯数と、最近の掛け軸(今日の一事)を見せる。タップで茶室が開く。

struct WidgetEntry: TimelineEntry {
    let date: Date
    let cupsToday: Int
    let matchaCups: Int
    let ichiji: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, cupsToday: 2, matchaCups: 1, ichiji: "英単語を三十")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // 日付が変わったら「今日」の杯数を数え直す。アプリ側の変更時は reloadAllTimelines で即更新
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(at: .now), entry(at: midnight)], policy: .after(midnight)))
    }

    private func entry(at date: Date) -> WidgetEntry {
        let record = SharedStore.load() ?? TeaRecord()
        return WidgetEntry(date: date, cupsToday: record.cupsToday(now: date), matchaCups: record.matchaCups, ichiji: record.latestIchiji)
    }
}

struct ShibuiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("今日は")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.cupsToday)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("杯")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Theme.Palette.text)
                Text("取り戻しました")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer(minLength: 0)
                Text(entry.matchaCups > 0 ? "挽いた抹茶 \(entry.matchaCups)杯" : "一服どうぞ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.matcha)
            }
            if family == .systemMedium, let ichiji = entry.ichiji {
                Spacer(minLength: 0)
                KakejikuMini(text: ichiji)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Theme.Palette.background, for: .widget)
        .widgetURL(SharedStore.openURL)
    }
}

/// ウィジェット用の小さな掛け軸(縦書き)
private struct KakejikuMini: View {
    let text: String
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.Palette.kogecha).frame(width: 58, height: 4)
            VStack(spacing: 1) {
                ForEach(Array(text.prefix(8).enumerated()), id: \.offset) { _, ch in
                    Text(String(ch)).font(.system(size: 12, weight: .medium, design: .serif))
                }
            }
            .foregroundStyle(Theme.Palette.kogecha)
            .frame(width: 44, height: 116)
            .background(Theme.Palette.shiro)
            .overlay(Rectangle().stroke(Theme.Palette.hai.opacity(0.4), lineWidth: 3))
            Capsule().fill(Theme.Palette.kogecha).frame(width: 58, height: 5)
        }
    }
}

@main
struct ShibuiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShibuiWidget", provider: Provider()) { entry in
            ShibuiWidgetView(entry: entry)
        }
        .configurationDisplayName("渋分")
        .description("今日取り戻した抹茶の杯数と、今日の一事を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    ShibuiWidget()
} timeline: {
    WidgetEntry(date: .now, cupsToday: 2, matchaCups: 1, ichiji: "英単語を三十")
}
