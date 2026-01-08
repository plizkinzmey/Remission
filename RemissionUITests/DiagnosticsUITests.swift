import XCTest

@MainActor
final class DiagnosticsUITests: BaseUITestCase {
    // swiftlint:disable:next function_body_length
    func testDiagnosticsOfflineBadgeAndClear() {
        let app = launchApp(
            arguments: [
                "--ui-testing-fixture=server-list-sample",
                "--ui-testing-scenario=diagnostics-sample"
            ]
        )
        let diagnosticsButton = openDiagnosticsButton(app)
        diagnosticsButton.tap()

        let firstRow = app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "diagnostics_log_row_")
            )
            .element(boundBy: 0)
        _ = firstRow.waitForExistence(timeout: 6)

        let offlineBadge = app.descendants(matching: .any)["diagnostics_offline_badge"].firstMatch
        let offlineTextRU = app.staticTexts["Офлайн"].firstMatch
        let offlineTextEN = app.staticTexts["Offline"].firstMatch
        let offlineMarker = app.descendants(matching: .any)["diagnostics_offline_badge_marker"]
            .firstMatch
        // Проверяем существование любого из индикаторов offline
        var badgeFound = false
        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline && !badgeFound {
            badgeFound =
                offlineBadge.exists || offlineTextRU.exists || offlineTextEN.exists
                || offlineMarker.exists
            if !badgeFound {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        XCTAssertTrue(badgeFound, "Offline badge missing")

        let limitNotice = app.staticTexts["diagnostics_limit_notice"].firstMatch
        XCTAssertTrue(limitNotice.waitForExistence(timeout: 3), "Limit notice missing")

        let clearButton = app.buttons["diagnostics_clear_button"].firstMatch
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3), "Clear button missing")
        clearButton.tap()

        XCTAssertTrue(
            firstRow.waitForDisappearance(timeout: 8),
            "Log rows did not disappear after clear"
        )
        let emptyState = app.otherElements["diagnostics_empty_state"].firstMatch
        let allRows = app.descendants(matching: .any)
            .matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "diagnostics_log_row_")
            )

        var cleared = false
        let clearedDeadline = Date().addingTimeInterval(8)
        while Date() < clearedDeadline && cleared == false {
            cleared = emptyState.exists || allRows.firstMatch.exists == false
            if cleared == false {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        XCTAssertTrue(cleared, "Empty state or cleared list missing after clear")

        let closeButton = app.buttons["diagnostics_close_button"].firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
        closeButton.tap()
        XCTAssertTrue(closeButton.waitForDisappearance(timeout: 3))
    }

    private func openDiagnosticsButton(_ app: XCUIApplication) -> XCUIElement {
        let window = app.windows.firstMatch
        let diagnosticsButton = window.buttons["server_detail_diagnostics_button"].firstMatch
        if diagnosticsButton.waitForExistence(timeout: 3) {
            return diagnosticsButton
        }

        let serverCell = window.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'server_list_item_'")
        ).firstMatch
        if serverCell.exists {
            serverCell.tap()
            let detailButton = window.buttons["server_detail_diagnostics_button"].firstMatch
            XCTAssertTrue(
                detailButton.waitForExistence(timeout: 5),
                "Diagnostics button missing"
            )
            return detailButton
        }

        XCTFail("Diagnostics button missing: no server detail or server list row found")
        return diagnosticsButton
    }
}
