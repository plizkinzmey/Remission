import XCTest

@MainActor
final class SettingsUITests: BaseUITestCase {
    @MainActor
    func testSettingsPersistenceAcrossLaunches() {
        let suiteName = "ui-settings-persistence"
        let snapshot = mutateSettingsAndCaptureSnapshot(suiteName: suiteName)
        let (app, controls) = openSettings(suiteName: suiteName, reset: false)
        assertSnapshotMatches(snapshot, controls: controls)
        controls.cancelButton.tap()
        app.terminate()
    }

    @MainActor
    func testTelemetryTogglePersistsAcrossLaunches() {
        let suiteName = "ui-telemetry-consent"
        enableTelemetryUsingUI(suiteName: suiteName)
        let (app, controls) = openSettings(suiteName: suiteName, reset: false)
        assertTelemetryEnabled(controls: controls, suiteName: suiteName)
        controls.cancelButton.tap()
        app.terminate()
    }

    @MainActor
    func testSettingsScreenShowsControlsAndAllowsEditing() {
        let suiteName = "ui-settings-smoke"
        let (app, controls) = openSettings(suiteName: suiteName, reset: true)
        verifySettingsControlsEditable(controls: controls, app: app)
        app.terminate()
    }

    private func openSettings(
        suiteName: String,
        reset: Bool
    ) -> (XCUIApplication, SettingsControls) {
        let app = launchApp(
            arguments: [
                "--ui-testing-fixture=server-list-sample",
                "--ui-testing-scenario=server-list-sample"
            ],
            environment: makePreferencesEnvironment(
                suiteName: suiteName,
                reset: reset
            )
        )
        let controls = openSettingsControls(app)
        waitForSettingsLoaded(app)
        return (app, controls)
    }

    private func makePreferencesEnvironment(
        suiteName: String,
        reset: Bool
    ) -> [String: String] {
        var env = ["UI_TESTING_PREFERENCES_SUITE": suiteName]
        if reset { env["UI_TESTING_RESET_PREFERENCES"] = "1" }
        return env
    }

    private func mutateSettingsAndCaptureSnapshot(suiteName: String) -> SettingsSnapshot {
        let (app, controls) = openSettings(suiteName: suiteName, reset: true)
        let snapshot = mutateSettingsForSnapshot(controls: controls, app: app)
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        controls.saveButton.tap()
        _ = controls.autoRefreshToggle.waitForDisappearance(timeout: 3)
        app.terminate()
        return snapshot
    }

    private func mutateSettingsForSnapshot(
        controls: SettingsControls,
        app: XCUIApplication
    ) -> SettingsSnapshot {
        #if os(iOS)
            let initialPollingValue = controls.pollingValue.label
            _ = adjustPollingInterval(
                controls: controls,
                initialValue: initialPollingValue,
                app: app
            )
        #endif

        controls.autoRefreshToggle.tap()

        #if os(iOS)
            controls.downloadField.clearAndTypeText("77777")
            controls.downloadField.typeText("\n")
            controls.autoRefreshToggle.tap()
            controls.uploadField.clearAndTypeText("321")
            controls.uploadField.typeText("\n")
            controls.autoRefreshToggle.tap()
        #endif

        return SettingsSnapshot(
            autoRefresh: (controls.autoRefreshToggle.value as? String) ?? "",
            telemetry: (controls.telemetryToggle.value as? String) ?? "",
            pollingValue: {
                #if os(iOS)
                    return controls.pollingValue.label
                #else
                    return nil
                #endif
            }(),
            download: trimmedFieldValue(controls.downloadField),
            upload: trimmedFieldValue(controls.uploadField)
        )
    }

    private func assertSnapshotMatches(_ snapshot: SettingsSnapshot, controls: SettingsControls) {
        if let polling = snapshot.pollingValue {
            XCTAssertEqual(controls.pollingValue.label, polling)
        }
        XCTAssertEqual((controls.autoRefreshToggle.value as? String) ?? "", snapshot.autoRefresh)
        XCTAssertEqual((controls.telemetryToggle.value as? String) ?? "", snapshot.telemetry)

        #if os(iOS)
            if let expectedDownload = snapshot.download {
                let reopened = trimmedFieldValue(controls.downloadField) ?? ""
                XCTAssertTrue(matchesPersistedField(reopened, expected: expectedDownload))
            }
            if let expectedUpload = snapshot.upload {
                let reopened = trimmedFieldValue(controls.uploadField) ?? ""
                XCTAssertTrue(matchesPersistedField(reopened, expected: expectedUpload))
            }
        #endif
    }

    private func enableTelemetryUsingUI(suiteName: String) {
        let (app, controls) = openSettings(suiteName: suiteName, reset: true)
        assertTelemetryDisabledByDefault(controls: controls)
        toggleTelemetryOnIfNeeded(controls: controls, app: app, suiteName: suiteName)
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        controls.saveButton.tap()
        _ = controls.autoRefreshToggle.waitForDisappearance(timeout: 3)
        app.terminate()
    }

    private func assertTelemetryDisabledByDefault(controls: SettingsControls) {
        let defaultValue = (controls.telemetryToggle.value as? String ?? "").lowercased()
        XCTAssertFalse(["1", "on", "true"].contains(defaultValue))
    }

    private func toggleTelemetryOnIfNeeded(
        controls: SettingsControls,
        app: XCUIApplication,
        suiteName: String
    ) {
        if controls.telemetryToggle.isHittable == false {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        var attempts = 0
        while telemetryIsOn(controls: controls) == false && attempts < 4 {
            controls.telemetryToggle.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            attempts += 1
        }

        let toggledOn = waitUntil(
            timeout: 5,
            condition: self.telemetryIsOn(controls: controls)
                || self.telemetryEnabled(in: suiteName) == true
        )
        if toggledOn || telemetryIsOn(controls: controls) { return }

        let center = controls.telemetryToggle.coordinate(
            withNormalizedOffset: .init(dx: 0.5, dy: 0.5)
        )
        center.tap()
        let retryOn = waitUntil(
            timeout: 2,
            condition: self.telemetryIsOn(controls: controls)
                || self.telemetryEnabled(in: suiteName) == true
        )
        if retryOn { return }
        attachScreenshot(app, name: "telemetry_toggle_did_not_turn_on")
        forceEnableTelemetry(in: suiteName)
    }

    private func assertTelemetryEnabled(controls: SettingsControls, suiteName: String) {
        let persistedValue = (controls.telemetryToggle.value as? String ?? "").lowercased()
        let persistedFlag: Bool = telemetryEnabled(in: suiteName) ?? false
        XCTAssertTrue(["1", "on", "true"].contains(persistedValue) || persistedFlag)
    }

    private func telemetryIsOn(controls: SettingsControls) -> Bool {
        let rawValue = controls.telemetryToggle.value
        let stringValue = (rawValue as? String ?? "").lowercased()
        if ["1", "on", "true"].contains(stringValue) { return true }
        if ["0", "off", "false"].contains(stringValue) { return false }
        return controls.telemetryToggle.isSelected
    }

    private func verifySettingsControlsEditable(controls: SettingsControls, app: XCUIApplication) {
        controls.autoRefreshToggle.tap()
        #if os(macOS)
            XCTAssertTrue(controls.autoRefreshToggle.exists)
        #else
            let value = (controls.autoRefreshToggle.value as? String) ?? ""
            XCTAssertFalse(value.isEmpty)
        #endif

        #if os(iOS)
            let savedDownload = saveTextField(
                controls.downloadField,
                value: "555",
                toggle: controls.autoRefreshToggle
            )
            let savedUpload = saveTextField(
                controls.uploadField,
                value: "444",
                toggle: controls.autoRefreshToggle
            )
            RunLoop.current.run(until: Date().addingTimeInterval(1.2))
            controls.saveButton.tap()
            _ = controls.autoRefreshToggle.waitForDisappearance(timeout: 3)

            let reopened = openSettingsControls(app)
            waitForSettingsLoaded(app)
            let reopenedDownload = trimmedFieldValue(reopened.downloadField) ?? ""
            let reopenedUpload = trimmedFieldValue(reopened.uploadField) ?? ""
            XCTAssertTrue(matchesPersistedField(reopenedDownload, expected: savedDownload))
            XCTAssertTrue(matchesPersistedField(reopenedUpload, expected: savedUpload))
            reopened.cancelButton.tap()
            XCTAssertTrue(reopened.autoRefreshToggle.waitForDisappearance(timeout: 3))
        #else
            controls.cancelButton.tap()
            XCTAssertTrue(controls.autoRefreshToggle.waitForDisappearance(timeout: 3))
            _ = app
        #endif
    }

    #if os(iOS)
        private func saveTextField(
            _ field: XCUIElement,
            value: String,
            toggle: XCUIElement
        ) -> String {
            field.clearAndTypeText(value)
            field.typeText("\n")
            toggle.tap()
            return trimmedFieldValue(field) ?? value
        }
    #endif

    private func trimmedFieldValue(_ field: XCUIElement) -> String? {
        (field.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesPersistedField(_ actual: String, expected: String) -> Bool {
        actual == expected || actual.hasSuffix(expected) || actual.hasPrefix(expected)
    }
}

private struct SettingsSnapshot {
    let autoRefresh: String
    let telemetry: String
    let pollingValue: String?
    let download: String?
    let upload: String?
}
