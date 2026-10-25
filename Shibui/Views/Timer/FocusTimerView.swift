import DesignSystem
import SwiftData
import SwiftUI
import UserNotifications

/// 集中タイマー(全画面)。時間は hh:mm のリングで決める(5 分〜3 時間)。
/// 見た目: 地面の水たまり(奥行きのある楕円)が残り時間の円グラフ。文字も水たまりと同じ平面に置く。
/// その横のししおどしに、かけいから水が少しずつ溜まり、1分ごとに傾いて水たまりへ水を落とし、戻るときに「カコン」。
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
    /// ししおどしが傾く間隔(秒)。設定で 1 秒きざみに変えられる(起動引数 `-shishiCycle 秒` でも)
    @AppStorage(FocusTimerView.shishiCycleKey) private var cycle = 60.0
    static let shishiCycleKey = "shishiCycle"

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
                        // 竹筒が戻った瞬間の振動(音はししおどしの絵の側で、動きに合わせて鳴らす)
                        .onChange(of: Int(elapsed / cycle)) { old, new in
                            if new > old, !finished { Haptics.impact() }
                        }
                }
                .accessibilityElement()
                .accessibilityLabel("集中のタイマー")
                Spacer(minLength: 0)
                soundButton
                // ボタンの形全体を押せるように、大きさと背景はボタンの中(label)につける
                Button { stop() } label: {
                    Text(finished ? "閉じる" : "終了")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.text)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                        .background(Theme.Palette.surface, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(PressScaleStyle())
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, Theme.Spacing.s)
            } else {
                Spacer()
                Text("集中する時間")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Palette.text)
                DurationDial(minutes: $minutes)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                soundButton
                VStack(spacing: Theme.Spacing.s) {
                    Button { start() } label: {
                        Label("はじめる", systemImage: "timer")
                            .font(.headline)
                            .foregroundStyle(Theme.Palette.shiro)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButton)
                            .background(Theme.Palette.matcha, in: .capsule)
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
        // 終わる時刻に通知(アプリを閉じていても届く)。画面確認の自動開始のときは、許可の画面を出さない
        if UserDefaults.standard.bool(forKey: "timerAutostart") { return }
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
/// - ししおどし: 御茶ノ水駅のししおどしのような、2本の支柱に竹筒をのせた形(岩などの囲いはなし)。Unity で作った 3D。
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
    /// 水が水面に届く点(画面上)と、口から出てから届くまでの時間
    @State private var landing: (point: CGPoint, time: Double)?

    var body: some View {
        // 1回のなかでの進み具合: 溜まる(〜最後の 2.4 秒手前)→ 傾いて落とす → 戻る
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let pourLength = min(2.4, cycle * 0.3)
        let fill = min(1, t / (cycle - pourLength))
        let pouring = t >= cycle - pourLength
        let pourT = pouring ? (t - (cycle - pourLength)) / pourLength : 0
        // 傾き: 0(水を受ける)→ 1(水を落とす)→ 0
        let tip = pouring ? sin(min(1, pourT) * .pi) : 0
        // 水が水面に届いてからの時間(波紋に使う)。口から水が出はじめる(傾き 0.55 をこえる)時刻 + 落ちる時間
        let emitStart = cycle - pourLength + pourLength * asin(0.55) / .pi
        let drop = emitStart + (landing?.time ?? 0.4)
        let sinceDrop: Double = {
            if elapsed < drop { return -1 }
            let since = t >= drop ? t - drop : t + cycle - drop
            return since <= 3 ? since : -1
        }()

        // 音: 水が届く(drop)→ 竹筒が戻る(cycle)の長さに、録音の「落ちはじめ→カコン」を合わせる
        let rate = min(3, max(0.5, (SoundBank.kakonOffset - SoundBank.pourOffset) / max(0.3, cycle - drop)))
        let soundStart = drop - SoundBank.shishiLeadIn / rate
        let soundCount = elapsed > 0 ? Int(floor((elapsed - soundStart) / cycle)) : -99
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // 地面の枯山水(砂紋・石・苔)。水たまりと同じ平面に寝かせ、水たまりのまわりは同心円の筋
                let pond = min(w * 0.9, 360)
                let ground = pond * 3.2
                KaresansuiGround(pondCenter: CGPoint(x: ground / 2, y: ground / 2), pondRadius: pond / 2)
                    .frame(width: ground, height: ground)
                    // 枯山水は水たまりを中心にした円の中だけ(斜めに倒すと楕円に見える)。ふちはぼかして、地面になじませる
                    // (開発者の指示: 赤線をふちに、境目はぼかす。ここだけ、ぼかしのためにグラデーションを使う)
                    .mask(RadialGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.82),
                                                 .init(color: .clear, location: 1)],
                                         center: .center, startRadius: 0, endRadius: pond * 1.28))
                    .rotation3DEffect(.degrees(62), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
                    .position(x: w * 0.5, y: h * 0.66)
                    .allowsHitTesting(false)
                // 水たまり(地面の平面)。輪と文字も同じ平面
                PondPlane(remainingFraction: remainingFraction, timeText: timeText, caption: caption, water: water)
                    .frame(width: min(w * 0.9, 360), height: min(w * 0.9, 360))
                    .rotation3DEffect(.degrees(62), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
                    .position(x: w * 0.5, y: h * 0.66)
                // 水が落ちた場所の波紋(水面に寝かせた楕円)。場所は 3D の水の放物線から求めている
                if sinceDrop >= 0, let p = landing?.point {
                    ForEach(0..<3, id: \.self) { k in
                        let r = max(0, sinceDrop - Double(k) * 0.35)
                        Ellipse()
                            .stroke(Color.white.opacity(max(0, 0.75 - r * 0.25)), lineWidth: 2)
                            .frame(width: 24 + r * 80, height: (24 + r * 80) * 0.36)
                            .position(p)
                    }
                    .allowsHitTesting(false)
                }

                // ししおどし(Unity で作った 3D)。水たまりの左上に立ち、傾くと水たまりへ水を落とす
                ShishiOdoshi3DView(fill: fill, tip: tip, pouring: pouring, waterY: h * 0.66 - 6,
                                   onLanding: { p, time in if landing == nil { landing = (p, time) } })
                    .frame(width: w, height: h * 0.72)
                    .position(x: w * 0.5, y: h * 0.36)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 560)
        .onChange(of: soundCount) { old, new in
            if new > old, new >= 0 { SoundBank.shared.shishi(rate: rate) }
        }
    }
}

/// 地面に置いた水たまりの平面(このビューごと斜めに倒して、奥行きを出す)
private struct PondPlane: View {
    let remainingFraction: Double
    let timeText: String
    let caption: String
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
            // 文字も水面と同じ平面に(水面と同じ角度で寝かせて見せる)
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
