import XCTest

final class RemissionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testShowsEmptyStateOnFirstLaunch() {
        let app = launchApp()

        let emptyTitle = app.staticTexts["Нет подключённых серверов"]
        XCTAssertTrue(emptyTitle.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Добавить сервер"].exists)
    }

    @MainActor
    func testSelectingServerOpensDetailScreen() {
        let app = launchApp(arguments: ["--ui-testing-fixture=server-list-sample"])

        let serverCell = app.buttons["UI Test NAS"]
        XCTAssertTrue(serverCell.waitForExistence(timeout: 2))
        serverCell.tap()

        let detailNavBar = app.navigationBars["UI Test NAS"]
        XCTAssertTrue(detailNavBar.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Адрес"].exists)
    }

    @discardableResult
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
        return app
    }
}
