import XCTest

/// タイマーの「終了」: 文字ではなく、ボタンの左はしを押しても反応するか。設定のししおどしの間隔も画面に残す
final class TimerButtonTests: XCTestCase {
    func testEndButtonEdge() {
        let app = XCUIApplication()
        app.launchArguments = ["-didOnboard", "YES", "-scene", "timer", "-timerAutostart", "YES"]
        app.launch()
        sleep(6)
        let end = app.buttons["終了"]
        print("END exists=\(end.exists) frame=\(end.frame)")
        // ボタンの左はし(文字から離れた所)を押す
        end.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5)).tap()
        sleep(3)
        print("RESULT closed=\(!app.buttons["終了"].exists) tabs=\(app.tabBars.firstMatch.exists)")
        app.tabBars.buttons["設定"].tap()
        sleep(1)
        app.swipeUp()
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "settings-shishi.png"))
        print("SHOT:" + NSTemporaryDirectory() + "settings-shishi.png")
    }
}
