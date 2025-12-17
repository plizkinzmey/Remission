import XCTest

@MainActor
final class RemissionUITests: BaseUITestCase {

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
    func testSettingsScreenShowsControls() {
        let app = launchApp()

        let controls = openSettingsControls(app)
        waitForSettingsLoaded(app)

        XCTAssertTrue(controls.autoRefreshToggle.exists, "Auto-refresh toggle missing")
        XCTAssertTrue(controls.pollingSlider.exists, "Polling slider missing")
        XCTAssertTrue(controls.downloadField.exists, "Download limit field missing")
        XCTAssertTrue(controls.uploadField.exists, "Upload limit field missing")

        controls.closeButton.tap()
        XCTAssertTrue(controls.autoRefreshToggle.waitForDisappearance(timeout: 3))
    }

}
