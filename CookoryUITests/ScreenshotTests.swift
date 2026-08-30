import XCTest

/// App Store 掲載用スクリーンショットを撮る。
///
/// デモデータは `-seedDemoData` でアプリ側が投入する。UI テストはクローンされた
/// シミュレータ上で動くため外部の simctl からは撮れない。XCUIScreen で撮って
/// xcresult の添付として持ち帰る。
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [DemoDataLaunchArgument]
        app.launch()
        // デモデータの投入（画像 10 枚の生成を含む）を待つ。
        Thread.sleep(forTimeInterval: 6)
    }

    func testCaptureAll() throws {
        capture(named: "01-home")

        try captureMealDetail()
        tapTab(index: 0)

        tapTab(index: 1)
        capture(named: "02-calendar")

        tapTab(index: 2)
        capture(named: "03-cookbook")

        try captureDishDetail()
    }

    /// 記録の詳細。写真・料理名・メモが出る。
    private func captureMealDetail() throws {
        let row = app.descendants(matching: .any)
            .matching(identifier: "recentMealRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "最近の料理が見つからない")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 2.5)

        capture(named: "05-meal-detail")

        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// 同じ料理の履歴。本アプリの中核価値を示す画面。
    private func captureDishDetail() throws {
        tapTab(index: 2)

        let row = app.descendants(matching: .any)
            .matching(identifier: "cookbookRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "図鑑の行が見つからない")
        // hittable でない場合に備えて座標でタップする。
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 2.5)

        // 詳細画面にしか無い要素で確認する。戻るボタンやナビゲーションバーは
        // 図鑑にも存在するため、遷移の失敗を検出できない。
        let cookCount = app.descendants(matching: .any)
            .matching(identifier: "dishCookCount").firstMatch
        XCTAssertTrue(
            cookCount.waitForExistence(timeout: 10), "詳細画面へ遷移していない"
        )

        capture(named: "04-dish-history")
    }

    // MARK: - 部品

    private func tapTab(index: Int) {
        let tabs = app.tabBars.buttons
        guard tabs.count > index else {
            XCTFail("タブが \(index + 1) 個未満: \(tabs.count)")
            return
        }
        tabs.element(boundBy: index).tap()
        Thread.sleep(forTimeInterval: 2)
    }

    private func capture(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

/// アプリ側の DemoDataSeeder.launchArgument と揃える。
/// UI テストからはアプリのモジュールを import できないため定数を置く。
private let DemoDataLaunchArgument = "-seedDemoData"
