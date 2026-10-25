import DesignSystem
import FamilyControls
import SwiftData
import SwiftUI

/// 設定。iOS 標準の Form で作る(SPEC 5章 I)。通知時刻(複数)・茶碗・振動・音・はじめの説明・記録の削除。
struct SettingsView: View {
    static func date(_ m: Int) -> Date { Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) ?? .now }
    static func minutes(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    @Environment(\.modelContext) private var context
    @State private var showsOnboarding = false
    @State private var showsTimePicker = false
    @State private var showsAppPicker = false
    @State private var guardState = ScreenGuard.shared
    @AppStorage(FocusTimerView.shishiCycleKey) private var shishiCycle = 60.0
    @State private var newTime = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now
    private let reminders = Reminders.shared
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @AppStorage(Haptics.storageKey) private var hapticsOn = true
    @State private var confirmsDeleteAll = false
    @AppStorage(SoundBank.ambientOnKey) private var ambientOn = false

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
                    ForEach(reminders.times, id: \.self) { m in
                        DatePicker("通知", selection: Binding(
                            get: { Self.date(m) },
                            set: { reminders.change(m, to: Self.minutes($0)) }
                        ), displayedComponents: .hourAndMinute)
                    }
                    .onDelete { idx in idx.map { reminders.times[$0] }.forEach(reminders.remove) }
                    // 押すと時刻を選ぶ画面が開く(前は、選ぶ前に勝手な時刻が足されていた)
                    Button("時刻を追加", systemImage: "plus") {
                        newTime = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now
                        showsTimePicker = true
                    }
                } header: {
                    Text("通知")
                } footer: {
                    Text("決めた時刻に毎日お知らせします。タップすると点てる画面が開きます。左にスワイプで消せます")
                }
                // SNS を見すぎたら茶室へ(Screen Time API)
                Section {
                    Toggle("見すぎたら知らせる", isOn: Binding(
                        get: { guardState.isOn },
                        set: { on in Task { if on { await guardState.start() } else { guardState.stop() } } }
                    ))
                    .tint(Theme.Palette.matcha)
                    Button {
                        Task { if await guardState.requestAuthorization() { showsAppPicker = true } }
                    } label: {
                        LabeledContent("見張るアプリ", value: guardState.selectedCount == 0 ? "選ぶ" : "\(guardState.selectedCount)件")
                    }
                    Picker("知らせるまでの時間", selection: Binding(
                        get: { guardState.minutes },
                        set: { guardState.minutes = $0; guardState.save(); if guardState.isOn { Task { await guardState.start() } } }
                    )) {
                        ForEach([1, 5, 10, 15, 30, 60], id: \.self) { Text("\($0)分").tag($0) }
                    }
                    if let m = guardState.message {
                        Text(m).font(.dsCaption).foregroundStyle(Theme.Palette.vermilion)
                    }
                } header: {
                    Text("SNS を見すぎたら")
                } footer: {
                    Text("選んだアプリを決めた時間使うと「そろそろ一服しませんか」と通知します。タップすると点てる画面が開きます(Screen Time を使います)")
                }
                .familyActivityPicker(isPresented: $showsAppPicker, selection: Binding(
                    get: { guardState.selection },
                    set: { guardState.selection = $0; guardState.save(); if guardState.isOn { Task { await guardState.start() } } }
                ))
                Section {
                    Stepper(value: $shishiCycle, in: 3...600, step: 1) {
                        LabeledContent("ししおどしの間隔", value: String(format: "%d分%02d秒", Int(shishiCycle) / 60, Int(shishiCycle) % 60))
                    }
                } header: {
                    Text("タイマー")
                } footer: {
                    Text("集中タイマー中に、ししおどしが傾いて「カコン」と鳴る間隔です(1秒きざみ。−/+ を押し続けると速く変わります)")
                }
                Section {
                    Toggle("振動", isOn: $hapticsOn)
                        .tint(Theme.Palette.matcha)
                }
                Section {
                    Toggle("点てるときの自然の音", isOn: $ambientOn)
                        .tint(Theme.Palette.matcha)
                    NatureMixer()
                } header: {
                    Text("音")
                } footer: {
                    Text("川・風・鳥の音量を、それぞれ決められます。点てるときは茶筅の音より小さく、ときどきししおどし。タイマー中は自然の音がずっと流れ、設定した間隔でししおどしが鳴ります")
                }
                Section {
                    Button("はじめの説明をもう一度見る", systemImage: "book") { showsOnboarding = true }
                }
                Section("音の出典") {
                    Text("川: jackthemurray (CC0) / 風: ezwa (パブリックドメイン) / 鳥のさえずり: Robert EA Harvey (CC BY-SA 4.0) / ししおどし: Fg2 (パブリックドメイン)。いずれも Wikimedia Commons")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                Section {
                    Button("記録をすべて消す", systemImage: "trash", role: .destructive) { confirmsDeleteAll = true }
                } footer: {
                    Text("1つずつ消すときは、振り返りで点をタップして消せます")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.background)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            // 通知の時刻を選ぶ(iOS 標準のドラム)。「追加」で足す、「やめる」なら何も足さない
            .sheet(isPresented: $showsTimePicker) {
                NavigationStack {
                    DatePicker("通知の時刻", selection: $newTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .navigationTitle("通知の時刻")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("やめる") { showsTimePicker = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("追加") {
                                    reminders.add(Self.minutes(newTime))
                                    showsTimePicker = false
                                }
                                .bold()
                            }
                        }
                }
                .presentationDetents([.height(340)])
                .presentationDragIndicator(.visible)
            }
            // はじめの説明は、この画面の上に全画面で開く(閉じると設定に戻る)
            .fullScreenCover(isPresented: $showsOnboarding) {
                OnboardingView { showsOnboarding = false }
            }
            .confirmationDialog("記録をすべて消しますか?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("すべて消す", role: .destructive) {
                    try? context.delete(model: MatchaSession.self)
                    try? context.delete(model: FocusSession.self)
                    try? context.save()
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("点てた記録と集中の記録がすべて消え、もとに戻せません。")
            }
        }
    }
}
