import DesignSystem
import SwiftUI
import WidgetKit

/// ホーム画面ウィジェット。アプリと同じ記録(App Group の JSON)を読んで、数と最新の記録を見せる。
/// タップするとアプリのホームが開く。

struct WidgetEntry: TimelineEntry {
    let date: Date
    let count: Int
    let latest: Record?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, count: 3, latest: Record(title: "ゴーヤ", note: "", date: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // アプリ側の保存時に reloadAllTimelines で更新される。念のため1時間ごとにも読み直す。
        completion(Timeline(entries: [current()], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func current() -> WidgetEntry {
        let entries = SharedStore.load()
        return WidgetEntry(date: .now, count: entries.count, latest: entries.first)
    }
}

struct ShibuiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("記録の数")
                .font(.caption2)
                .foregroundStyle(Theme.Palette.secondaryText)
            Text("\(entry.count)")
                .font(.system(size: family == .systemSmall ? 44 : 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.text)
            Spacer(minLength: 0)
            if let latest = entry.latest {
                Text("最新")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Text(latest.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                    .lineLimit(1)
            } else {
                Text("まだ記録がありません")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Theme.Palette.background, for: .widget)
        .widgetURL(SharedStore.openURL)
    }
}

@main
struct ShibuiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShibuiWidget", provider: Provider()) { entry in
            ShibuiWidgetView(entry: entry)
        }
        .configurationDisplayName("Shibui")
        .description("記録の数と、最新の記録を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ShibuiWidget()
} timeline: {
    WidgetEntry(date: .now, count: 3, latest: Record(title: "ゴーヤ", note: "", date: .now))
}
