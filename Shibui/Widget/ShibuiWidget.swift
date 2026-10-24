import DesignSystem
import SwiftUI
import WidgetKit

/// ホーム画面ウィジェット。浮いたお金と、次に食べごろになる柿(または熟した柿)を見せる。タップでアプリが開く。

struct WidgetEntry: TimelineEntry {
    let date: Date
    let saved: Int
    let next: Kaki?
    let ripeCount: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, saved: 12_000, next: MockData.sample, ripeCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        // 次の柿が熟す時刻と、その先1時間おきに描き直す。アプリ側の変更時は reloadAllTimelines で即更新
        let kakis = (SharedStore.load() ?? []).filter { $0.decision == nil }
        var dates = [Date.now]
        dates += kakis.map(\.ripeAt).filter { $0 > .now }.sorted().prefix(5)
        dates += (1...6).map { Date.now.addingTimeInterval(Double($0) * 3600) }
        completion(Timeline(entries: dates.sorted().map { entry(at: $0) }, policy: .atEnd))
    }

    private func entry(at date: Date) -> WidgetEntry {
        let kakis = SharedStore.load() ?? []
        let hanging = kakis.filter { $0.decision == nil }.sorted { $0.ripeAt < $1.ripeAt }
        return WidgetEntry(
            date: date,
            saved: SharedStore.savedAmount(kakis),
            next: hanging.first,
            ripeCount: hanging.filter { $0.isRipe(at: date) }.count
        )
    }
}

struct ShibuiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("浮いたお金")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Text(entry.saved.yen)
                    .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.Palette.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                status
            }
            if family == .systemMedium, let next = entry.next {
                Spacer(minLength: 0)
                DryView(kind: next.kind, ripeness: next.ripeness(at: entry.date), size: 72, showsString: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Theme.Palette.background, for: .widget)
        .widgetURL(entry.ripeCount > 0 ? URL(string: "shibui://ripe")! : SharedStore.openURL)
    }

    @ViewBuilder
    private var status: some View {
        if entry.ripeCount > 0 {
            Label("\(entry.ripeCount)個 食べごろ", systemImage: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.vermilion)
        } else if let next = entry.next {
            VStack(alignment: .leading, spacing: 2) {
                Text(next.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                    .lineLimit(1)
                Text(next.ripeAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
        } else {
            Text("軒下は空です")
                .font(.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
        }
    }
}

@main
struct ShibuiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShibuiWidget", provider: Provider()) { entry in
            ShibuiWidgetView(entry: entry)
        }
        .configurationDisplayName("ほしいも")
        .description("浮いたお金と、次に食べごろになる欲しい物を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

enum MockData {
    static let sample = Kaki(name: "ワイヤレスイヤホン", price: 24_800, hungAt: .now.addingTimeInterval(-5 * 86_400), dryingSeconds: 7 * 86_400)
}

#Preview(as: .systemMedium) {
    ShibuiWidget()
} timeline: {
    WidgetEntry(date: .now, saved: 12_000, next: MockData.sample, ripeCount: 0)
}
