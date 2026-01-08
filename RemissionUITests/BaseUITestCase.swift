import XCTest

@MainActor
class BaseUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launching & Navigation

    @MainActor
    func launchApp(
        arguments: [String] = [],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        dismissOnboarding: Bool = true
    ) -> XCUIApplication {
        var env = environment
        env["UI_TESTING"] = "1"

        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment = env
        app.launch()

        #if os(macOS)
            app.activate()
            _ = app.wait(for: .runningForeground, timeout: 5)
            normalizeWindows(app)
        #endif

        if dismissOnboarding {
            dismissOnboardingIfNeeded(app)
        }
        return app
    }

    @MainActor
    private func normalizeWindows(_ app: XCUIApplication) {
        let primaryWindow = app.windows.firstMatch
        if primaryWindow.waitForExistence(timeout: 4) == false {
            app.activate()
            openNewWindowIfNeeded(app)
            if primaryWindow.waitForExistence(timeout: 4) == false {
                app.typeKey("n", modifierFlags: .command)
                _ = primaryWindow.waitForExistence(timeout: 4)
            }
        }

        if primaryWindow.waitForExistence(timeout: 2) {
            if primaryWindow.isHittable {
                primaryWindow.click()
            } else {
                // Если окно не кликается, попробуем активировать приложение.
                app.activate()
            }
        }
    }

    @MainActor
    func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let cancelButton = app.buttons["onboarding_cancel_button"].firstMatch
        guard cancelButton.waitForExistence(timeout: 6) else { return }
        cancelButton.tap()
        if cancelButton.waitForDisappearance(timeout: 3) == false {
            attachScreenshot(app, name: "onboarding_cancel_sticky")
        }
    }

    // MARK: - Telemetry helpers

    @MainActor
    func telemetryEnabled(in suite: String) -> Bool? {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: "user_preferences") else {
            return nil
        }
        do {
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return object?["isTelemetryEnabled"] as? Bool
        } catch {
            return nil
        }
    }

    @MainActor
    func forceEnableTelemetry(in suite: String) {
        guard let defaults = UserDefaults(suiteName: suite) else { return }

        let fallbackObject: [String: Any] = [
            "version": 2,
            "pollingInterval": 5,
            "isAutoRefreshEnabled": true,
            "isTelemetryEnabled": false,
            "defaultSpeedLimits": [
                "downloadKilobytesPerSecond": NSNull(),
                "uploadKilobytesPerSecond": NSNull()
            ]
        ]

        let currentObject: [String: Any] = {
            guard let data = defaults.data(forKey: "user_preferences") else {
                return fallbackObject
            }
            guard
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else {
                return fallbackObject
            }
            return object
        }()

        var updated = currentObject
        updated["isTelemetryEnabled"] = true
        if let newData = try? JSONSerialization.data(withJSONObject: updated) {
            defaults.set(newData, forKey: "user_preferences")
            defaults.synchronize()
        }
    }

    // MARK: - Generic helpers

    @MainActor
    func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.25,
        condition: @escaping @autoclosure () -> Bool,
        onTick: @escaping () -> Void = {}
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
            onTick()
        }
        return condition()
    }

    @MainActor
    func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openNewWindowIfNeeded(_ app: XCUIApplication) {
        guard app.windows.allElementsBoundByIndex.isEmpty else { return }

        let fileMenu = app.menuBars.menuBarItems["File"].firstMatch
        let fileMenuRu = app.menuBars.menuBarItems["Файл"].firstMatch
        let resolvedFileMenu = fileMenu.exists ? fileMenu : fileMenuRu

        if resolvedFileMenu.waitForExistence(timeout: 1) {
            resolvedFileMenu.click()
            let newWindowItem = app.menuBars.menuItems["New Window"].firstMatch
            let newWindowItemRu = app.menuBars.menuItems["Новое окно"].firstMatch
            let resolvedNewWindow = newWindowItem.exists ? newWindowItem : newWindowItemRu
            if resolvedNewWindow.waitForExistence(timeout: 1) {
                resolvedNewWindow.click()
            }
        }
    }
}

@MainActor
extension BaseUITestCase {
    // MARK: - Settings helpers

    func openSettingsControls(_ app: XCUIApplication) -> SettingsControls {
        let window = app.windows.firstMatch
        tapSettingsButton(in: window, app: app)
        let closeButton = waitForSettingsSheet(in: window, app: app)
        waitForSettingsLoaded(app)

        let autoRefreshToggle = app.descendants(matching: .any)["settings_auto_refresh_toggle"]
            .firstMatch
        waitForSettingsControls(app, autoRefreshToggle: autoRefreshToggle)
        ensureSettingsTopVisible(app, autoRefreshToggle: autoRefreshToggle)
        requireExists(autoRefreshToggle, in: app, debugName: "settings_auto_refresh_toggle")

        let telemetryToggle = app.descendants(matching: .any)["settings_telemetry_toggle"]
        XCTAssertTrue(telemetryToggle.waitForExistence(timeout: 5), "Telemetry toggle missing")

        let telemetryPolicyLink =
            app.descendants(matching: .any)["settings_telemetry_policy_link"]
        assertExists(telemetryPolicyLink, in: app, message: "Telemetry policy link missing")

        let pollingSlider = app.sliders["settings_polling_slider"]
        assertExists(pollingSlider, in: app, message: "Polling slider missing")

        let pollingValue = app.staticTexts["settings_polling_value"]
        assertExists(pollingValue, in: app, message: "Polling value missing")

        let downloadField = app.textFields["settings_download_limit_field"]
        assertExists(downloadField, in: app, message: "Download limit field missing")

        let uploadField = app.textFields["settings_upload_limit_field"]
        assertExists(uploadField, in: app, message: "Upload limit field missing")

        return SettingsControls(
            autoRefreshToggle: autoRefreshToggle,
            telemetryToggle: telemetryToggle,
            telemetryPolicyLink: telemetryPolicyLink,
            pollingSlider: pollingSlider,
            pollingValue: pollingValue,
            downloadField: downloadField,
            uploadField: uploadField,
            closeButton: closeButton
        )
    }

    private func tapSettingsButton(in window: XCUIElement, app: XCUIApplication) {
        #if os(macOS)
            app.activate()
            if window.waitForExistence(timeout: 2), window.isHittable {
                window.click()
            }
        #endif

        let detailSettingsButton = window.buttons["server_detail_edit_button"].firstMatch
        if detailSettingsButton.waitForExistence(timeout: 2) {
            detailSettingsButton.isHittable
                ? detailSettingsButton.tap()
                : detailSettingsButton.forceTap()
            return
        }

        let serverCell = window.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'server_list_item_'")
        ).firstMatch
        if serverCell.exists {
            serverCell.tap()
            let detailButton = window.buttons["server_detail_edit_button"].firstMatch
            XCTAssertTrue(
                detailButton.waitForExistence(timeout: 5),
                "Server settings button missing"
            )
            detailButton.isHittable ? detailButton.tap() : detailButton.forceTap()
            return
        }

        XCTFail("Settings button missing: no server detail or server list row found")
    }

    private func waitForSettingsSheet(
        in window: XCUIElement,
        app: XCUIApplication
    ) -> XCUIElement {
        #if os(macOS)
            let closeButton = window.sheets.firstMatch.buttons["settings_close_button"]
                .firstMatch
            let altCloseButton = app.buttons["settings_close_button"].firstMatch

            if closeButton.waitForExistence(timeout: 3) || altCloseButton.exists {
                return closeButton.exists ? closeButton : altCloseButton
            }

            // Fallback: try keyboard shortcut and re-tap toolbar button.
            app.typeKey(",", modifierFlags: .command)
            if closeButton.waitForExistence(timeout: 2) || altCloseButton.exists {
                return closeButton.exists ? closeButton : altCloseButton
            }

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "settings_close_button_missing"
            attachment.lifetime = .keepAlways
            add(attachment)
            let tree = app.debugDescription
            XCTFail("Close button missing. Tree: \(tree)")
            return closeButton
        #else
            let closeButton = app.buttons["settings_close_button"].firstMatch
            XCTAssertTrue(closeButton.waitForExistence(timeout: 4), "Close button missing")
            return closeButton
        #endif
    }

    private func waitForSettingsControls(
        _ app: XCUIApplication,
        autoRefreshToggle: XCUIElement
    ) {
        if autoRefreshToggle.waitForExistence(timeout: 2) { return }
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline && autoRefreshToggle.exists == false {
            waitForSettingsLoaded(app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    private func ensureSettingsTopVisible(_ app: XCUIApplication, autoRefreshToggle: XCUIElement) {
        #if os(macOS)
            revealSettingsTopOnMac(app)
        #else
            revealSettingsTopOnIOS(app, autoRefreshToggle: autoRefreshToggle)
        #endif
    }

    private func revealSettingsTopOnMac(_ app: XCUIApplication) {
        if let scrollView = app.scrollViews.allElementsBoundByIndex.first {
            _ = scrollView.waitForExistence(timeout: 1)
            guard scrollView.isHittable else { return }
            scrollView.swipeUp()
        }
    }

    private func revealSettingsTopOnIOS(_ app: XCUIApplication, autoRefreshToggle: XCUIElement) {
        let table = app.tables.firstMatch
        let collection = app.collectionViews.firstMatch
        let scrollView = app.scrollViews.firstMatch

        for _ in 0..<15 where autoRefreshToggle.exists == false {
            table.swipeDownIfExists()
            collection.swipeDownIfExists()
            scrollView.swipeDownIfExists()
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        if autoRefreshToggle.exists == false {
            dragToTop(preferred: collection, fallback: table, lastFallback: scrollView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    private func dragToTop(
        preferred: XCUIElement,
        fallback: XCUIElement,
        lastFallback: XCUIElement
    ) {
        if preferred.exists {
            preferred.dragToTop()
        } else if fallback.exists {
            fallback.dragToTop()
        } else if lastFallback.exists {
            lastFallback.dragToTop()
        }
    }

    private func requireExists(_ element: XCUIElement, in app: XCUIApplication, debugName: String) {
        if element.waitForExistence(timeout: 5) { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(debugName)_missing"
        attachment.lifetime = .keepAlways
        add(attachment)
        let tree = app.debugDescription
        let path = "/tmp/remission-ui-tree.txt"
        try? tree.write(toFile: path, atomically: true, encoding: .utf8)
        XCTFail("\(debugName) missing. Tree written to \(path)")
    }

    private func assertExists(
        _ element: XCUIElement,
        in app: XCUIApplication,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        #if os(iOS)
            if element.waitForExistence(timeout: 3) == false {
                let scrollable: XCUIElement
                if app.tables.firstMatch.exists {
                    scrollable = app.tables.firstMatch
                } else if app.collectionViews.firstMatch.exists {
                    scrollable = app.collectionViews.firstMatch
                } else if app.scrollViews.firstMatch.exists {
                    scrollable = app.scrollViews.firstMatch
                } else {
                    scrollable = app
                }

                for _ in 0..<10 where element.exists == false {
                    scrollable.swipeUp()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
                }
            }
        #endif
        XCTAssertTrue(element.waitForExistence(timeout: 2), message, file: file, line: line)
    }

    func waitForSettingsLoaded(_ app: XCUIApplication) {
        let loadingRu = app.staticTexts["Загружаем настройки…"]
        let loadingEn = app.staticTexts["Loading settings..."]
        if loadingRu.exists || loadingEn.exists {
            _ = loadingRu.waitForDisappearance(timeout: 5)
            _ = loadingEn.waitForDisappearance(timeout: 5)
        } else {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }

    func adjustPollingInterval(
        controls: SettingsControls,
        initialValue: String,
        app: XCUIApplication
    ) -> Bool {
        let initialSliderValue = controls.pollingSlider.value as? String ?? ""
        let changed = {
            controls.pollingValue.label != initialValue
                || (controls.pollingSlider.value as? String ?? "") != initialSliderValue
        }

        if controls.pollingSlider.isHittable == false {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        let normalizedPositions: [CGFloat] = [0.9, 0.1]
        for position in normalizedPositions {
            controls.pollingSlider.adjust(toNormalizedSliderPosition: position)
            if waitUntil(timeout: 4, condition: changed()) { return true }
        }

        guard controls.pollingSlider.isHittable else {
            attachScreenshot(app, name: "polling_slider_not_hittable")
            return false
        }

        let dragTargets: [CGFloat] = [1.0, 0.0, 0.75, 0.25, 0.5]
        let center = controls.pollingSlider.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )
        for targetX in dragTargets {
            let target = controls.pollingSlider.coordinate(
                withNormalizedOffset: CGVector(dx: targetX, dy: 0.5)
            )
            center.press(forDuration: 0.4, thenDragTo: target)
            if waitUntil(timeout: 4, condition: changed()) { return true }
        }

        attachScreenshot(app, name: "polling_slider_no_change")
        return false
    }
}

extension XCUIElement {
    fileprivate func swipeDownIfExists() {
        guard exists else { return }
        swipeDown()
    }

    fileprivate func forceTap() {
        let coordinate = self.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }

    fileprivate func dragToTop() {
        let start = coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.9))
        let end = coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
        start.press(forDuration: 0.01, thenDragTo: end)
    }
}

// MARK: - Shared UI handles

struct SettingsControls {
    let autoRefreshToggle: XCUIElement
    let telemetryToggle: XCUIElement
    let telemetryPolicyLink: XCUIElement
    let pollingSlider: XCUIElement
    let pollingValue: XCUIElement
    let downloadField: XCUIElement
    let uploadField: XCUIElement
    let closeButton: XCUIElement
}

// MARK: - Extensions

@MainActor
extension XCUIElement {
    func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return exists == false
    }

    func clearAndTypeText(_ text: String) {
        tap()
        if let value = self.value as? String {
            let deleteString = String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: value.count
            )
            typeText(deleteString)
        }
        typeText(text)
    }
}
