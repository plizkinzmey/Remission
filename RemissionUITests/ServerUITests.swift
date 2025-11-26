import XCTest

@MainActor
final class ServerUITests: BaseUITestCase {

    // MARK: - Server Detail Tests

    func testSelectingServerOpensDetailScreen() {
        let app = launchApp(
            arguments: [
                "--ui-testing-fixture=server-list-sample",
                "--ui-testing-scenario=server-list-sample"
            ]
        )
        let identifier = "server_list_item_11111111-1111-1111-1111-111111111111"
        #if os(macOS)
            var serverCell = app.buttons.matching(identifier: identifier).firstMatch
            if serverCell.exists == false {
                serverCell = app.staticTexts["UI Test NAS"]
            }
        #else
            let serverCell = app.buttons[identifier]
        #endif
        let exists = serverCell.waitForExistence(timeout: 10)
        if exists == false {
            XCTFail("Server cell not found. Tree: \(app.debugDescription)")
            return
        }
        serverCell.tap()

        verifyServerDetailScreen(app)
    }

    // MARK: - Settings Tests

    func testSettingsScreenShowsControlsAndAllowsEditing() {
        let suiteName = "ui-settings-smoke"
        let app = launchApp(
            environment: [
                "UI_TESTING_PREFERENCES_SUITE": suiteName,
                "UI_TESTING_RESET_PREFERENCES": "1"
            ]
        )
        let controls = openSettingsControls(app)
        waitForSettingsLoaded(app)

        verifyAutoRefreshToggle(controls)
        adjustPollingSlider(controls)
        let savedUploadInSession = updateLimitFields(controls)

        controls.closeButton.tap()
        XCTAssertTrue(
            controls.autoRefreshToggle.waitForDisappearance(timeout: 3),
            "Settings sheet did not close"
        )

        verifyPersistedValues(app, savedUploadInSession: savedUploadInSession)
    }

    // MARK: - Private Helpers

    private func verifyServerDetailScreen(_ app: XCUIApplication) {
        #if os(macOS)
            let addressLabelRu = app.staticTexts["Адрес"]
            let addressLabelEn = app.staticTexts["Address"]
            let addressExists =
                addressLabelRu.waitForExistence(timeout: 5)
                || addressLabelEn.waitForExistence(timeout: 5)
            XCTAssertTrue(addressExists)
        #else
            let detailNavBar = app.navigationBars["UI Test NAS"]
            let detailTitle = app.staticTexts["UI Test NAS"]

            let opened = waitUntil(
                timeout: 10, condition: detailNavBar.exists || detailTitle.exists)
            if opened == false {
                attachScreenshot(app, name: "server_detail_not_opened")
            }
            XCTAssertTrue(opened, "Server detail screen did not appear")

            RunLoop.current.run(until: Date().addingTimeInterval(1.0))

            let addressLabel = app.staticTexts["Адрес"]
            let addressLabelEn = app.staticTexts["Address"]
            let addressAppeared = waitUntil(
                timeout: 8,
                condition: addressLabel.exists || addressLabelEn.exists,
                onTick: {
                    if !addressLabel.exists && !addressLabelEn.exists {
                        app.swipeUp()
                    }
                }
            )

            if addressAppeared == false {
                attachScreenshot(app, name: "server_detail_no_address")
            }
            XCTAssertTrue(addressAppeared, "Address label missing after wait and scroll")
        #endif
    }

    private func verifyAutoRefreshToggle(_ controls: SettingsControls) {
        controls.autoRefreshToggle.tap()
        let autoValue = (controls.autoRefreshToggle.value as? String) ?? ""
        #if os(macOS)
            XCTAssertTrue(controls.autoRefreshToggle.exists, "Auto-refresh toggle отсутствует")
        #else
            XCTAssertFalse(autoValue.isEmpty, "Auto-refresh toggle не реагирует")
        #endif
    }

    private func adjustPollingSlider(_ controls: SettingsControls) {
        #if os(iOS)
            if controls.pollingSlider.exists {
                controls.pollingSlider.adjust(toNormalizedSliderPosition: 0.2)
            }
        #endif
    }

    private func updateLimitFields(_ controls: SettingsControls) -> String? {
        #if os(iOS)
            controls.downloadField.clearAndTypeText("555")
            controls.uploadField.clearAndTypeText("444")
            let savedUploadInSession = (controls.uploadField.value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            return savedUploadInSession
        #else
            return nil
        #endif
    }

    private func verifyPersistedValues(_ app: XCUIApplication, savedUploadInSession: String?) {
        #if os(iOS)
            let controls = openSettingsControls(app)
            waitForSettingsLoaded(app)
            let reopenedDownloadRaw = controls.downloadField.value as? String ?? ""
            let reopenedUploadRaw = controls.uploadField.value as? String ?? ""
            let reopenedDownload = reopenedDownloadRaw.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let reopenedUpload = reopenedUploadRaw.trimmingCharacters(in: .whitespacesAndNewlines)

            let downloadMatches =
                reopenedDownload == "555"
                || reopenedDownload.hasSuffix("555")
                || reopenedDownload.hasPrefix("555")

            let expectedUpload = (savedUploadInSession ?? "444")
            let uploadMatches =
                reopenedUpload == expectedUpload
                || reopenedUpload.hasSuffix(expectedUpload)
                || reopenedUpload.hasPrefix(expectedUpload)

            XCTAssertTrue(
                downloadMatches,
                "Download limit не сохраняется внутри сессии (\(reopenedDownloadRaw))"
            )
            XCTAssertTrue(
                uploadMatches,
                "Upload limit не сохраняется внутри сессии (\(reopenedUploadRaw))"
            )
        #endif
    }
}
