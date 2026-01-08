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
        _ = openSettingsControls(app)
        waitForSettingsLoaded(app)

        let diagnosticsButton = app.buttons["settings_diagnostics_button"].firstMatch
        var foundDiagnostics = diagnosticsButton.waitForExistence(timeout: 3)
        if foundDiagnostics == false {
            let containers: [XCUIElement] = [
                app.tables.firstMatch,
                app.collectionViews.firstMatch,
                app.scrollViews.firstMatch
            ]
            for _ in 0..<12 where foundDiagnostics == false {
                for container in containers where container.exists {
                    container.swipeUp()
                }
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                foundDiagnostics = diagnosticsButton.exists
                if foundDiagnostics { break }
            }
            if foundDiagnostics == false {
                foundDiagnostics = diagnosticsButton.waitForExistence(timeout: 5)
            }
        }
        XCTAssertTrue(foundDiagnostics, "Diagnostics button missing")
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
}
