import DesignSystem
import SwiftData
import SwiftUI

@main
struct ShibuiApp: App {
    /// はじめの説明を見終えたか。起動引数 `-resetOnboarding` で未読に戻せる(実機・シミュレーターの確認用)
    @AppStorage("didOnboard") private var didOnboard = false

    init() {
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
