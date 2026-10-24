import DesignSystem
import SwiftData
import SwiftUI

/// 設定。iOS 標準の Form で作る(SPEC 5章 I)。茶碗・振動・はじめの説明・記録の削除。
/// 通知時刻は M5 で加える。
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didOnboard") private var didOnboard = true
    @AppStorage(ChawanStyle.storageKey) private var style = ChawanStyle.shino
    @AppStorage(Haptics.storageKey) private var hapticsOn = true
    @State private var confirmsDeleteAll = false

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
                    Button("はじめの説明をもう一度見る", systemImage: "book") { didOnboard = false }
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
