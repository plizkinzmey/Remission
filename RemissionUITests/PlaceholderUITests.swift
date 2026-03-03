import XCTest

@MainActor
final class PlaceholderUITests: XCTestCase {
    func testServerListFixtureLoadsWithoutBlocking() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-fixture=server-list-sample"]
        app.launch()

        dismissServerFormIfPresented(app)

        // Smoke-критерий: UI должен дойти до одного из ожидаемых стабильных экранов.
        let hasServerRow = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "server_list_item_")
        ).firstMatch
        let hasEmptyStateAdd = app.buttons["server_list_add_button"]
        let hasToolbarAdd = app.buttons["app_add_server_button"]

        XCTAssertTrue(
            waitForAnyToAppear([hasServerRow, hasEmptyStateAdd, hasToolbarAdd], timeout: 12),
            "App did not reach a stable server-list UI state"
        )

        app.terminate()
    }

    private func dismissServerFormIfPresented(_ app: XCUIApplication) {
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 1.5) {
            cancelButton.tap()
        }
    }

    private func waitForAnyToAppear(_ elements: [XCUIElement], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
