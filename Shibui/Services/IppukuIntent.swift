import AppIntents

/// 「一服する」(5章 K)。アクションボタン・ショートカット・Siri から呼べる。
/// 実行するとアプリを開き、点てる(本体)を直接表示する(通知から開いたときと同じ)。
struct IppukuIntent: AppIntent {
    static let title: LocalizedStringResource = "一服する"
    static let description = IntentDescription("抹茶を点てる画面を開きます。作業の前の儀式に。")
    /// アプリを前に出して実行する
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Reminders.shared.openTemae = true
        return .result()
    }
}

/// App Shortcuts として登録する。設定 → アクションボタン → ショートカット で「一服する」を選べる
struct OtemaeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: IppukuIntent(),
                    phrases: ["\(.applicationName)で一服する", "\(.applicationName)で一服"],
                    shortTitle: "一服する",
                    systemImageName: "cup.and.saucer")
    }
}
