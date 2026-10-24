import XCTest

/// 通知の入口: 設定で1分後の時刻を足し、ホーム画面に出て待ち、届いた通知をタップすると点てる画面が開くか
final class ReminderTests: XCTestCase {
    func testNotificationOpensTemae() {
        let app = XCUIApplication()
        app.launchArguments = ["-didOnboard", "YES"]
        addUIInterruptionMonitor(withDescription: "通知の許可") { alert in
            let allow = alert.buttons["許可"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()
        sleep(2)
        app.tabBars.buttons["設定"].tap()
        sleep(1)
        app.buttons["時刻を追加"].tap()
        sleep(2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["許可"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        print("TIMES:", app.datePickers.count)
        // アプリを閉じた状態で通知を受ける(実際の使い方に近い)
        app.terminate()
        print("BACKGROUNDED")
        // 通知が届くまで待つ(最大 90 秒)
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "一杯の時間です")).firstMatch
        let found = banner.waitForExistence(timeout: 90)
        print("BANNER:", found)
        if found {
            banner.tap()
            _ = app.wait(for: .runningForeground, timeout: 10)
            sleep(5)
            print("APPSTATE:", app.state.rawValue, "buttons:", app.buttons.allElementsBoundByIndex.prefix(10).map(\.label))
            print("OPENED_TEMAE:", app.buttons["やめる"].exists)
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "after-notif.png"))
            print("SHOT:" + NSTemporaryDirectory() + "after-notif.png")
        }
    }
}
