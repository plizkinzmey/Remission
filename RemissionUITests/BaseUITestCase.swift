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
            if app.windows.allElementsBoundByIndex.isEmpty {
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
            }
        #endif

        if dismissOnboarding {
            dismissOnboardingIfNeeded(app)
        }
        return app
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

    // MARK: - Settings helpers

    @MainActor
    func openSettingsControls(_ app: XCUIApplication) -> SettingsControls {
        let settingsButton = app.buttons["app_settings_button"].firstMatch
        #if os(macOS)
            let toolbarFallback = app.toolbars.buttons["Настройки"].firstMatch
            if settingsButton.exists == false && toolbarFallback.exists {
                toolbarFallback.tap()
            } else {
                XCTAssertTrue(
                    settingsButton.waitForExistence(timeout: 5), "Settings button missing")
                settingsButton.tap()
            }
        #else
            XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button missing")
            settingsButton.tap()
        #endif

        // Дождаться завершения загрузки настроек
        let loadingText = app.staticTexts["Загружаем настройки…"]
        if loadingText.waitForExistence(timeout: 2) {
            _ = loadingText.waitForDisappearance(timeout: 5)
        }

        let autoRefreshToggle = app.descendants(matching: .any)["settings_auto_refresh_toggle"]
            .firstMatch

        #if os(macOS)
            // Form на macOS может открываться не в начале: скроллим вверх, чтобы материализовать верхние элементы.
            let scrollBar = app.scrollBars.element(boundBy: 0)
            if scrollBar.waitForExistence(timeout: 2) {
                scrollBar.adjust(toNormalizedSliderPosition: 0.0)
            }
        #else
            // На iOS Form основана на UITableView/UICollectionView/UIScrollView — прокручиваем вверх, пока не появится toggle.
            let table = app.tables.firstMatch
            let collection = app.collectionViews.firstMatch
            let scrollView = app.scrollViews.firstMatch

            for _ in 0..<15 where autoRefreshToggle.exists == false {
                if table.exists { table.swipeDown() }
                if collection.exists { collection.swipeDown() }
                if scrollView.exists { scrollView.swipeDown() }
                app.swipeDown()
                // короткая задержка, чтобы UI успел отрисовать новые ячейки
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }

            // Если не нашли — выполнить drag до верхнего края основного scrollable container.
            if autoRefreshToggle.exists == false {
                if collection.exists {
                    let start = collection.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.9))
                    let end = collection.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
                    start.press(forDuration: 0.01, thenDragTo: end)
                } else if table.exists {
                    let start = table.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.9))
                    let end = table.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
                    start.press(forDuration: 0.01, thenDragTo: end)
                } else if scrollView.exists {
                    let start = scrollView.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.9))
                    let end = scrollView.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.1))
                    start.press(forDuration: 0.01, thenDragTo: end)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        #endif

        // autoRefreshSection теперь первая секция в Form и должна быть видна сразу
        if autoRefreshToggle.waitForExistence(timeout: 5) == false {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "settings_auto_refresh_missing"
            attachment.lifetime = .keepAlways
            add(attachment)
            let tree = app.debugDescription
            let path = "/tmp/remission-ui-tree.txt"
            try? tree.write(toFile: path, atomically: true, encoding: .utf8)
            XCTFail("Auto-refresh toggle missing. Tree written to \(path)")
        }

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

        let closeButton = app.buttons["settings_close_button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button missing")

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

    @MainActor
    func waitForSettingsLoaded(_ app: XCUIApplication) {
        let loading = app.staticTexts["Загружаем настройки…"]
        if loading.exists {
            _ = loading.waitForDisappearance(timeout: 5)
        } else {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }

    @MainActor
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

        // Сделать слайдер видимым/доступным
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

        // Fallback: press+drag from center to target offsets
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

        let currentObject: [String: Any] = {
            if let data = defaults.data(forKey: "user_preferences"),
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            {
                return object
            }
            // Фолбэк: базовые значения по умолчанию, если prefs ещё не сохранены
            return [
                "version": 2,
                "pollingInterval": 5,
                "isAutoRefreshEnabled": true,
                "isTelemetryEnabled": false,
                "defaultSpeedLimits": [
                    "downloadKilobytesPerSecond": NSNull(),
                    "uploadKilobytesPerSecond": NSNull()
                ]
            ]
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
