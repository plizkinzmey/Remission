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
        let identifier = "server_list_item_11111111-1111-1111-1111-111111111111"
        #if os(macOS)
            var serverCell = app.buttons[identifier]
            if serverCell.exists == false {
                serverCell = app.staticTexts["UI Test NAS"]
            }
        #else
            let serverCell = app.buttons[identifier]
        #endif
        let exists = serverCell.waitForExistence(timeout: 5)
        if exists == false {
            XCTFail("Server cell not found. Tree: \(app.debugDescription)")
            return
        }
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
        dismissOnboardingIfNeeded(app)
        return app
    }

    @MainActor
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let cancelButton = app.buttons["onboarding_cancel_button"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
            _ = cancelButton.waitForDisappearance(timeout: 1)
        }
    }
}

@MainActor
extension XCUIElement {
    fileprivate func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return exists == false
    }
}
