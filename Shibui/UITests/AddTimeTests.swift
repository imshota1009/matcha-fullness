import XCTest

/// 設定の「時刻を追加」: 押すと時刻を選ぶ画面が出て、「追加」を押したときだけ時刻が足されるか
final class AddTimeTests: XCTestCase {
    func testAddTimeShowsPicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-didOnboard", "YES"]
        app.launch()
        sleep(2)
        app.tabBars.buttons["設定"].tap()
        sleep(1)
        let before = app.datePickers.count
        app.buttons["時刻を追加"].tap()
        sleep(2)
        let sheetOpen = app.navigationBars["通知の時刻"].exists
        let afterOpen = app.datePickers.count
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "addtime.png"))
        print("SHOT:" + NSTemporaryDirectory() + "addtime.png")
        app.buttons["やめる"].tap()
        sleep(1)
        let afterCancel = app.datePickers.count
        app.buttons["時刻を追加"].tap()
        sleep(1)
        app.buttons["追加"].tap()
        sleep(2)
        print("RESULT sheet=\(sheetOpen) before=\(before) withSheet=\(afterOpen) afterCancel=\(afterCancel) afterAdd=\(app.datePickers.count)")
    }
}
