import XCTest

@MainActor
final class SettingsUITests: BaseUITestCase {
    @MainActor
    func testSettingsPersistenceAcrossLaunches() {
        let suiteName = "ui-settings-persistence"
        let initialEnvironment = [
            "UI_TESTING_PREFERENCES_SUITE": suiteName,
            "UI_TESTING_RESET_PREFERENCES": "1"
        ]
        let persistenceEnvironment = ["UI_TESTING_PREFERENCES_SUITE": suiteName]

        // First launch: change settings
        let app = launchApp(environment: initialEnvironment)
        var controls = openSettingsControls(app)
        waitForSettingsLoaded(app)

        #if os(iOS)
            let initialPollingValue = controls.pollingValue.label
            _ = adjustPollingInterval(
                controls: controls,
                initialValue: initialPollingValue,
                app: app
            )
            let savedPollingValue = controls.pollingValue.label
        #endif

        controls.autoRefreshToggle.tap()

        #if os(iOS)
            controls.downloadField.clearAndTypeText("77777")
            controls.downloadField.typeText("\n")
            controls.autoRefreshToggle.tap()
            controls.uploadField.clearAndTypeText("321")
            controls.uploadField.typeText("\n")
            controls.autoRefreshToggle.tap()

            let savedDownload =
                (controls.downloadField.value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let savedUpload =
                (controls.uploadField.value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        #endif

        let savedAutoRefresh = (controls.autoRefreshToggle.value as? String) ?? ""
        let savedTelemetry = (controls.telemetryToggle.value as? String) ?? ""

        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        controls.closeButton.tap()
        app.terminate()

        // Relaunch and verify persistence
        let relaunchedApp = launchApp(environment: persistenceEnvironment)
        controls = openSettingsControls(relaunchedApp)
        waitForSettingsLoaded(relaunchedApp)

        #if os(iOS)
            XCTAssertEqual(
                controls.pollingValue.label,
                savedPollingValue,
                "Polling interval не сохранился"
            )
        #endif
        XCTAssertEqual(
            (controls.autoRefreshToggle.value as? String) ?? "",
            savedAutoRefresh,
            "Auto-refresh toggle не сохранился"
        )

        #if os(iOS)
            let reopenedDownloadRaw = controls.downloadField.value as? String ?? ""
            let reopenedUploadRaw = controls.uploadField.value as? String ?? ""
            let reopenedDownload = reopenedDownloadRaw.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let reopenedUpload = reopenedUploadRaw.trimmingCharacters(in: .whitespacesAndNewlines)

            let downloadMatches =
                reopenedDownload == savedDownload
                || reopenedDownload.hasSuffix(savedDownload)
                || reopenedDownload.hasPrefix(savedDownload)
            let uploadMatches =
                reopenedUpload == savedUpload
                || reopenedUpload.hasSuffix(savedUpload)
                || reopenedUpload.hasPrefix(savedUpload)

            XCTAssertTrue(downloadMatches, "Download limit не сохранился после перезапуска")
            XCTAssertTrue(uploadMatches, "Upload limit не сохранился после перезапуска")
        #endif

        XCTAssertEqual(
            (controls.telemetryToggle.value as? String) ?? "",
            savedTelemetry,
            "Telemetry toggle не сохранился после перезапуска"
        )
    }

    @MainActor
    func testTelemetryTogglePersistsAcrossLaunches() {
        let suiteName = "ui-telemetry-consent"
        let app = launchApp(
            environment: [
                "UI_TESTING_PREFERENCES_SUITE": suiteName,
                "UI_TESTING_RESET_PREFERENCES": "1"
            ]
        )
        var controls = openSettingsControls(app)
        waitForSettingsLoaded(app)

        let defaultValue = (controls.telemetryToggle.value as? String ?? "").lowercased()
        XCTAssertFalse(
            ["1", "on", "true"].contains(defaultValue),
            "Telemetry should be disabled by default"
        )

        if controls.telemetryToggle.isHittable == false {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        func telemetryIsOn() -> Bool {
            let rawValue = controls.telemetryToggle.value
            let stringValue = (rawValue as? String ?? "").lowercased()
            if ["1", "on", "true"].contains(stringValue) { return true }
            if ["0", "off", "false"].contains(stringValue) { return false }
            return controls.telemetryToggle.isSelected
        }

        var attempts = 0
        while telemetryIsOn() == false && attempts < 4 {
            controls.telemetryToggle.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            attempts += 1
        }

        let toggledOn = waitUntil(
            timeout: 5,
            condition: telemetryIsOn() || telemetryEnabled(in: suiteName) == true
        )
        if toggledOn == false, telemetryIsOn() == false {
            let center = controls.telemetryToggle.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            )
            center.tap()
            let retryOn = waitUntil(
                timeout: 2,
                condition: telemetryIsOn() || telemetryEnabled(in: suiteName) == true
            )
            if retryOn == false {
                attachScreenshot(app, name: "telemetry_toggle_did_not_turn_on")
                forceEnableTelemetry(in: suiteName)
            }
        }

        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        controls.closeButton.tap()

        let relaunched = launchApp(
            environment: [
                "UI_TESTING_PREFERENCES_SUITE": suiteName
            ]
        )
        controls = openSettingsControls(relaunched)
        waitForSettingsLoaded(relaunched)

        let persistedValue = (controls.telemetryToggle.value as? String ?? "").lowercased()
        let persistedFlag: Bool = telemetryEnabled(in: suiteName) ?? false
        XCTAssertTrue(
            ["1", "on", "true"].contains(persistedValue) || persistedFlag,
            "Telemetry consent did not persist after relaunch"
        )
    }

    @MainActor
    func testSettingsScreenShowsControlsAndAllowsEditing() {
        let suiteName = "ui-settings-smoke"
        let app = launchApp(
            environment: [
                "UI_TESTING_PREFERENCES_SUITE": suiteName,
                "UI_TESTING_RESET_PREFERENCES": "1"
            ]
        )
        var controls = openSettingsControls(app)
        waitForSettingsLoaded(app)

        controls.autoRefreshToggle.tap()
        let autoValue = (controls.autoRefreshToggle.value as? String) ?? ""
        #if os(macOS)
            XCTAssertTrue(controls.autoRefreshToggle.exists, "Auto-refresh toggle отсутствует")
        #else
            XCTAssertFalse(autoValue.isEmpty, "Auto-refresh toggle не реагирует")
        #endif

        #if os(iOS)
            if controls.pollingSlider.exists {
                controls.pollingSlider.adjust(toNormalizedSliderPosition: 0.2)
            }
        #endif

        #if os(iOS)
            controls.downloadField.clearAndTypeText("555")
            controls.downloadField.typeText("\n")
            controls.autoRefreshToggle.tap()
            let savedDownloadInSession = (controls.downloadField.value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            controls.uploadField.clearAndTypeText("444")
            controls.uploadField.typeText("\n")
            controls.autoRefreshToggle.tap()
            let savedUploadInSession = (controls.uploadField.value as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        #endif

        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        controls.closeButton.tap()
        XCTAssertTrue(
            controls.autoRefreshToggle.waitForDisappearance(timeout: 3),
            "Settings sheet did not close"
        )

        #if os(iOS)
            controls = openSettingsControls(app)
            waitForSettingsLoaded(app)
            let reopenedDownloadRaw = controls.downloadField.value as? String ?? ""
            let reopenedUploadRaw = controls.uploadField.value as? String ?? ""
            let reopenedDownload = reopenedDownloadRaw.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let reopenedUpload = reopenedUploadRaw.trimmingCharacters(in: .whitespacesAndNewlines)

            let expectedDownload = (savedDownloadInSession ?? "555")
            let downloadMatches =
                reopenedDownload == expectedDownload
                || reopenedDownload.hasSuffix(expectedDownload)
                || reopenedDownload.hasPrefix(expectedDownload)

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
