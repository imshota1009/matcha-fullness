import DesignSystem
import SwiftData
import SwiftUI
import UserNotifications

/// 集中タイマー(全画面)。15 / 25 / 50 分から選ぶ。
/// 見た目: 地面の水たまり(奥行きのある楕円)が残り時間の円グラフ。文字も水たまりと同じ平面に置く。
/// その横のししおどしに、かけいから水が少しずつ溜まり、5分ごとに傾いて水たまりへ水を落とし、戻るときに「カコン」。
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
    @State private var showsSound = false

    private static let notificationID = "focus-timer-end"
    /// ししおどしが傾く間隔(秒)。起動引数 `-shishiCycle 秒` で短くできる(画面確認用)
    private var cycle: Double {
        let v = UserDefaults.standard.double(forKey: "shishiCycle")
        return v > 0 ? v : 300
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            if let startedAt, let endAt {
                TimelineView(.animation) { context in
                    let now = context.date
                    let remaining = max(0, endAt.timeIntervalSince(now))
                    let total = endAt.timeIntervalSince(startedAt)
                    let elapsed = now.timeIntervalSince(startedAt)
                    ShishiOdoshiPond(remainingFraction: remaining / total,
                                     timeText: Self.format(remaining),
                                     caption: finished ? "おつかれさまでした" : "集中しています",
                                     cycle: cycle, elapsed: finished ? 0 : elapsed)
                        .onChange(of: remaining == 0) { _, done in if done { complete() } }
                        .onChange(of: Int(elapsed / cycle)) { old, new in
                            // 傾いて水を落とし、戻ったところで「カコン」
                            if new > old, !finished { SoundBank.shared.kakon(); Haptics.impact() }
                        }
                }
                .accessibilityElement()
                .accessibilityLabel("集中のタイマー")
                Spacer(minLength: 0)
                soundButton
                Button(finished ? "閉じる" : "終了") { stop() }
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.text)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                    .background(Theme.Palette.surface, in: .capsule)
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.s)
            } else {
                Spacer()
                Text("集中する時間")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                Picker("集中する時間", selection: $minutes) {
                    ForEach([15, 25, 50], id: \.self) { Text("\($0)分").tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                soundButton
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
        .sheet(isPresented: $showsSound) {
            NavigationStack {
                Form {
                    Section {
                        NatureMixer()
                    } footer: {
                        Text("好きな音を、好きな大きさで。0% にすると、その音は鳴りません")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.Palette.background)
                .navigationTitle("自然の音")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { CloseButton() }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            // 起動引数 `-timerAutostart YES` ですぐ始める(画面確認用)
            if UserDefaults.standard.bool(forKey: "timerAutostart"), startedAt == nil { start() }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// 自然の音の音量(川・風・鳥の3本)を開く
    private var soundButton: some View {
        Button { showsSound = true } label: {
            Label("自然の音", systemImage: "slider.horizontal.3")
                .font(.dsCaption.weight(.medium))
                .foregroundStyle(Theme.Palette.secondaryText)
                .frame(minHeight: Theme.Size.minTouch)
        }
    }

    private func start() {
        let now = Date()
        let end = now.addingTimeInterval(Double(minutes * 60))
        startedAt = now
        endAt = end
        Haptics.selection()
        // 自然の音がずっと流れる(ししおどしの「カコン」は、絵が傾くのに合わせて鳴らす)
        SoundBank.shared.startAmbient(shishiEvery: .infinity, forTimer: true)
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
        SoundBank.shared.stopAmbient()
        Haptics.success()
        record(until: endAt ?? .now, completed: true)
    }

    private func stop() {
        SoundBank.shared.stopAmbient()
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

/// ししおどしと水たまり。
/// - 水たまり: 地面に置いた円を斜めから見た形(奥行きのある楕円)。残り時間を藍の輪で示し、文字も同じ平面に置く
/// - ししおどし: 御茶ノ水駅のししおどしのような、2本の支柱に竹筒をのせた形(岩などの囲いはなし)。
///   かけい(上の細い竹)から水が落ちて竹筒に溜まり(中の水位が見える)、満ちると傾いて水たまりへ水を落とす
struct ShishiOdoshiPond: View {
    let remainingFraction: Double
    let timeText: String
    let caption: String
    let cycle: Double
    let elapsed: Double

    private let bamboo = Color(red: 0.62, green: 0.66, blue: 0.36)
    private let bambooDark = Color(red: 0.45, green: 0.48, blue: 0.24)
    private let wood = Color(red: 0.42, green: 0.32, blue: 0.22)
    private let water = Color(red: 0.62, green: 0.74, blue: 0.84)

    var body: some View {
        // 1回のなかでの進み具合: 溜まる(〜最後の 2.4 秒手前)→ 傾いて落とす → 戻る
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let pourLength = min(2.4, cycle * 0.3)
        let fill = min(1, t / (cycle - pourLength))
        let pouring = t >= cycle - pourLength
        let pourT = pouring ? (t - (cycle - pourLength)) / pourLength : 0
        // 傾き: 0(水を受ける)→ 1(水を落とす)→ 0
        let tip = pouring ? sin(min(1, pourT) * .pi) : 0
        // 水が落ちてからの時間(波紋に使う)。新しい回のはじめの 3 秒
        let sinceDrop = t < 3 && elapsed > cycle ? t : (pouring && pourT > 0.45 ? 0 : -1)

        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // 水たまり(地面の平面)。輪と文字も同じ平面
                PondPlane(remainingFraction: remainingFraction, timeText: timeText, caption: caption, ripple: sinceDrop, water: water)
                    .frame(width: min(w * 0.9, 360), height: min(w * 0.9, 360))
                    .rotation3DEffect(.degrees(62), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
                    .position(x: w * 0.56, y: h * 0.66)

                Canvas { ctx, size in
                    let pivot = CGPoint(x: w * 0.30, y: h * 0.26)
                    // 支柱2本と横木
                    for dx in [-14.0, 14.0] {
                        ctx.fill(Path(roundedRect: CGRect(x: pivot.x + dx - 5, y: pivot.y - 4, width: 10, height: h * 0.16), cornerRadius: 3), with: .color(wood))
                    }
                    // かけい(水を送る細い竹)と、落ちる水
                    let spoutEnd = CGPoint(x: pivot.x + 70, y: pivot.y - 92)
                    ctx.fill(Path(roundedRect: CGRect(x: spoutEnd.x - 4, y: spoutEnd.y - 8, width: 120, height: 12), cornerRadius: 6), with: .color(bambooDark))
                    if !pouring {
                        var stream = Path()
                        stream.move(to: CGPoint(x: spoutEnd.x + 2, y: spoutEnd.y + 4))
                        stream.addLine(to: CGPoint(x: spoutEnd.x + 2, y: pivot.y - 48))
                        ctx.stroke(stream, with: .color(water), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [6, 5], dashPhase: CGFloat(-elapsed * 40)))
                    }
                    // 竹筒(しっぽ → 口)。受けるときは口が上、満ちると口が下がる
                    let restAngle = -32.0 * .pi / 180, pourAngle = 28.0 * .pi / 180
                    let angle = restAngle + (pourAngle - restAngle) * tip
                    var c = ctx
                    c.translateBy(x: pivot.x, y: pivot.y)
                    c.rotate(by: .radians(angle))
                    let tube = CGRect(x: -60, y: -13, width: 150, height: 26)
                    c.fill(Path(roundedRect: tube, cornerRadius: 12), with: .color(bamboo))
                    // 中に溜まった水(口の側から見える。水位は fill)
                    let level = CGFloat(fill) * 0.9
                    c.fill(Path(roundedRect: CGRect(x: 90 - 70 * level - 8, y: -8, width: 70 * level + 6, height: 16), cornerRadius: 6),
                           with: .color(water.opacity(pouring ? 1 - pourT : 0.95)))
                    // 節と、斜めに切った口
                    c.fill(Path(CGRect(x: 18, y: -13, width: 3, height: 26)), with: .color(bambooDark))
                    var mouth = Path()
                    mouth.move(to: CGPoint(x: 90, y: -13)); mouth.addLine(to: CGPoint(x: 78, y: 13))
                    c.stroke(mouth, with: .color(bambooDark), lineWidth: 3)
                    // 軸
                    ctx.fill(Path(ellipseIn: CGRect(x: pivot.x - 5, y: pivot.y - 5, width: 10, height: 10)), with: .color(wood))
                    // 傾いたとき、口から水たまりへ落ちる水
                    if pouring, pourT > 0.25, pourT < 0.8 {
                        let mouthPt = CGPoint(x: pivot.x + cos(angle) * 88, y: pivot.y + sin(angle) * 88)
                        let target = CGPoint(x: w * 0.42, y: h * 0.47)
                        var arc = Path()
                        arc.move(to: mouthPt)
                        arc.addQuadCurve(to: target, control: CGPoint(x: target.x - 10, y: mouthPt.y + 10))
                        ctx.stroke(arc, with: .color(water), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    }
                }
                .scaleEffect(1.3, anchor: UnitPoint(x: 0.30, y: 0.26))
                .allowsHitTesting(false)
            }
        }
        .frame(height: 560)
    }
}

/// 地面に置いた水たまりの平面(このビューごと斜めに倒して、奥行きを出す)
private struct PondPlane: View {
    let remainingFraction: Double
    let timeText: String
    let caption: String
    /// 水が落ちてからの秒(0〜3)。負なら波紋なし
    let ripple: Double
    let water: Color

    var body: some View {
        ZStack {
            // 水たまり(ふちは少しゆがんだ丸)
            Ellipse().fill(water.opacity(0.55))
                .scaleEffect(x: 1.06, y: 1)
            Circle().stroke(water, lineWidth: 2).padding(6)
            // 残り時間の輪(藍)
            Circle().stroke(Theme.Palette.ai.opacity(0.15), lineWidth: 12).padding(22)
            Circle()
                .trim(from: 0, to: remainingFraction)
                .stroke(Theme.Palette.ai, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(22)
            // 落ちた水の波紋
            if ripple >= 0 {
                ForEach(0..<3, id: \.self) { k in
                    let r = max(0, ripple - Double(k) * 0.35)
                    Circle()
                        .stroke(Color.white.opacity(max(0, 0.7 - r * 0.25)), lineWidth: 2)
                        .frame(width: 30 + r * 70, height: 30 + r * 70)
                        .offset(x: -70, y: -40)
                }
            }
            // 文字も水面の平面に
            VStack(spacing: 4) {
                Text(timeText)
                    .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Palette.ai)
                Text(caption)
                    .font(.dsCaption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.ai.opacity(0.8))
            }
        }
    }
}
