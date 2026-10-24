import XCTest

/// 設定のシートを一番下までスクロールして、画面を残す(白い余白が出ないかの確認用)
final class SettingsScrollTests: XCTestCase {
    func testScrollSettingsToBottom() {
        let app = XCUIApplication()
        app.launchArguments = ["-didOnboard", "YES", "-sheet", ProcessInfo.processInfo.environment["SHEET"] ?? "history"]
        app.launch()
        sleep(3)
        print("BEFORE", app.scrollViews.firstMatch.frame, app.buttons["記録をすべて消す"].frame)
        for _ in 0..<6 { app.swipeUp(); usleep(400_000) }
        sleep(3)
        print("AFTER", app.scrollViews.firstMatch.frame, app.buttons["記録をすべて消す"].frame)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "settings-bottom.png"))
        print("SHOT:" + NSTemporaryDirectory() + "settings-bottom.png")
    }
}
