import DesignSystem
import SwiftData
import SwiftUI
import UserNotifications

/// 集中タイマー(全画面)。15 / 25 / 50 分から選ぶ。
/// 残り時間は終了予定の時刻から計算する(アプリを閉じてもずれない)。終わると通知と振動。
/// 「終了」でいつでも止められ、実際に集中した時間を記録する。
struct FocusTimerView: View {
    let matchaID: UUID?
    let onDone: () -> Void
    @Environment(\.modelContext) private var context
    @State private var minutes = 25
    @State private var startedAt: Date?
    @State private var endAt: Date?
    @State private var finished = false

    private static let notificationID = "focus-timer-end"

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            if let startedAt, let endAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, endAt.timeIntervalSince(context.date))
                    let total = endAt.timeIntervalSince(startedAt)
                    ZStack {
                        Circle().stroke(Theme.Palette.separator, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: remaining / total)
                            .stroke(Theme.Palette.ai, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(Self.format(remaining))
                                .font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.Palette.text)
                                .contentTransition(.numericText())
                            Text(finished ? "おつかれさまでした" : "集中しています")
                                .font(.dsCaption)
                                .foregroundStyle(Theme.Palette.secondaryText)
                        }
                    }
                    .frame(width: 260, height: 260)
                    .onChange(of: remaining == 0) { _, done in if done { complete() } }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("残り \(Int(remaining) / 60)分")
                }
                Spacer()
                Button(finished ? "閉じる" : "終了") { stop() }
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                    .background(Theme.Palette.surface, in: .capsule)
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.s)
            } else {
                Text("集中する時間")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                Picker("集中する時間", selection: $minutes) {
                    ForEach([15, 25, 50], id: \.self) { Text("\($0)分").tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                VStack(spacing: Theme.Spacing.s) {
                    Button { start() } label: {
                        Label("はじめる", systemImage: "timer")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.shiro)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                            .background(Theme.Palette.ai, in: .capsule)
                    }
                    .buttonStyle(PressScaleStyle())
                    Button("やめる") { onDone() }
                        .font(.dsBody)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .frame(minHeight: Theme.Size.minTouch)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.bottom, Theme.Spacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.background)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func start() {
        let now = Date()
        let end = now.addingTimeInterval(Double(minutes * 60))
        startedAt = now
        endAt = end
        Haptics.selection()
        // 終わる時刻に通知(アプリを閉じていても届く)
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let content = UNMutableNotificationContent()
            content.title = "集中の時間が終わりました"
            content.body = "おつかれさまでした。ひと息つきましょう"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSinceNow, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        Haptics.success()
        record(until: endAt ?? .now, completed: true)
    }

    private func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        if !finished { record(until: .now, completed: false) }
        onDone()
    }

    private func record(until end: Date, completed: Bool) {
        guard let startedAt else { return }
        context.insert(FocusSession(startedAt: startedAt, endedAt: end, plannedMinutes: minutes, completed: completed, matchaID: matchaID))
        try? context.save()
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
