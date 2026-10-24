import XCTest

/// はじめの説明を「次へ」だけで最後まで進められるか。設定から見直したときも同じか
final class OnboardingTests: XCTestCase {
    func testWalkThrough() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding"]
        app.launch()
        sleep(2)
        walk(app, label: "first")
        // 設定から、もう一度
        app.tabBars.buttons["設定"].tap()
        sleep(1)
        app.buttons["はじめの説明をもう一度見る"].tap()
        sleep(3)
        print("AFTER TAP: tabs=\(app.tabBars.firstMatch.exists) next=\(app.buttons["次へ"].exists) skip=\(app.buttons["スキップ"].exists) buttons=\(app.buttons.allElementsBoundByIndex.prefix(12).map(\.label))")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "after-tap.png"))
        print("SHOT:" + NSTemporaryDirectory() + "after-tap.png")
        walk(app, label: "replay")
    }

    private func walk(_ app: XCUIApplication, label: String) {
        for step in 0..<6 {
            let next = app.buttons["次へ"], start = app.buttons["茶室に入る"]
            if app.tabBars.firstMatch.exists && !next.exists && !start.exists { print("RESULT \(label): reached tabs after \(step) taps"); return }
            if next.exists { print("STEP \(label) \(step): 次へ hittable=\(next.isHittable)"); next.tap() }
            else if start.exists { print("STEP \(label) \(step): 茶室に入る hittable=\(start.isHittable)"); start.tap() }
            else { print("STEP \(label) \(step): no button"); }
            sleep(2)
        }
        print("RESULT \(label): STUCK. buttons=\(app.buttons.allElementsBoundByIndex.map(\.label))")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "stuck-\(label).png"))
        print("SHOT:" + NSTemporaryDirectory() + "stuck-\(label).png")
    }
}
