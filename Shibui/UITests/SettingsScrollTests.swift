import XCTest

/// タブを順に開いて画面を残す(見た目の確認用)。設定は一番下までスクロールして、白い余白が出ないかも見る
final class SettingsScrollTests: XCTestCase {
    func testTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-didOnboard", "YES"]
        app.launch()
        sleep(3)
        for (name, file) in [("振り返り", "tab-review"), ("設定", "tab-settings")] {
            app.tabBars.buttons[name].tap()
            sleep(2)
            if name == "設定" { for _ in 0..<4 { app.swipeUp() }; sleep(2) }
            let path = NSTemporaryDirectory() + file + ".png"
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
            print("SHOT:" + path)
        }
    }
}
