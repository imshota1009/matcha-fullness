import DesignSystem
import SwiftData
import SwiftUI
import UIKit

@main
struct ShibuiApp: App {
    /// はじめの説明を見終えたか。起動引数 `-resetOnboarding` で未読に戻せる(実機・シミュレーターの確認用)
    @AppStorage("didOnboard") private var didOnboard = false

    /// 通知のタップを受け取るため、起動のはじめに用意する
    private let reminders = Reminders.shared

    init() {
        // 見出し(ナビゲーションのタイトル)はヒラギノ明朝(SPEC 4章の例外。iOS 標準搭載のフォント)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        if let mincho = UIFont(name: "HiraMinProN-W6", size: 17) {
            appearance.titleTextAttributes = [.font: mincho]
        }
        if let large = UIFont(name: "HiraMinProN-W6", size: 32) {
            appearance.largeTitleTextAttributes = [.font: large]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        if CommandLine.arguments.contains("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: "didOnboard")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if didOnboard {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    OnboardingView { didOnboard = true }
                        .transition(.opacity)
                }
            }
            .animation(.spring(duration: 0.4), value: didOnboard)
            .modelContainer(for: [MatchaSession.self, FocusSession.self])
            .tint(Theme.Palette.accent)
            .preferredColorScheme(Theme.colorScheme)
        }
    }
}
