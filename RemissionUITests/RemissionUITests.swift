import XCTest

final class RemissionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testShowsEmptyStateOnFirstLaunch() {
        let app = launchApp()

        #if os(macOS)
            let emptyTitle = app.descendants(matching: .any)["server_list_empty_title"]
            XCTAssertTrue(emptyTitle.waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["server_list_add_button"].exists)
        #else
            let emptyTitle = app.staticTexts["server_list_empty_title"]
            XCTAssertTrue(emptyTitle.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["server_list_add_button"].exists)
        #endif
    }

    @MainActor
    func testSelectingServerOpensDetailScreen() {
        let app = launchApp(arguments: ["--ui-testing-fixture=server-list-sample"])

        #if os(macOS)
            let serverCell = app.descendants(matching: .any)[
                "server_list_item_11111111-1111-1111-1111-111111111111"
            ]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5))
        #else
            let serverCell = app.buttons["server_list_item_11111111-1111-1111-1111-111111111111"]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5))
        #endif
        serverCell.tap()

        #if os(macOS)
            let addressLabel = app.staticTexts["Адрес"]
            XCTAssertTrue(addressLabel.waitForExistence(timeout: 5))
        #else
            let detailNavBar = app.navigationBars["UI Test NAS"]
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Адрес"].exists)
        #endif
    }

    @discardableResult
    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
        #if os(macOS)
            app.activate()
            _ = app.wait(for: .runningForeground, timeout: 5)
            let fileMenu = app.menuBars.menuBarItems["File"]
            if fileMenu.waitForExistence(timeout: 2) {
                fileMenu.click()
                let newWindowItem = fileMenu.menus.menuItems["New Window"]
                if newWindowItem.waitForExistence(timeout: 1) {
                    newWindowItem.click()
                } else {
                    app.typeKey("n", modifierFlags: .command)
                }
            } else {
                app.typeKey("n", modifierFlags: .command)
            }
        #endif
        return app
    }
}
