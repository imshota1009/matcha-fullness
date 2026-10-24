import DesignSystem
import SwiftUI

@main
struct ShibuiApp: App {
    @State private var store = EntryStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(store)
            .tint(Theme.Palette.accent)
            .preferredColorScheme(Theme.colorScheme)
        }
    }
}
