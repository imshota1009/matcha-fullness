import DesignSystem
import SwiftData
import SwiftUI

/// 設定。iOS 標準の Form で作る(SPEC 5章 I)。茶碗・振動・はじめの説明・記録の削除。
/// 通知時刻は M5 で加える。
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var showsOnboarding = false
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
                    Text("川・風・鳥の音量を、それぞれ決められます。点てるときは茶筅の音より小さく、ときどきししおどし。タイマー中は自然の音がずっと流れ、5分ごとにししおどしが鳴ります")
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
