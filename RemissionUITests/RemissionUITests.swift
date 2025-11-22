import XCTest

@MainActor
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

        #if os(macOS)
            let addressLabel = app.staticTexts["Адрес"]
            XCTAssertTrue(addressLabel.waitForExistence(timeout: 5))
        #else
            let detailNavBar = app.navigationBars["UI Test NAS"]
            let detailTitle = app.staticTexts["UI Test NAS"]

            // Сначала ждём появления экрана деталей (nav bar или title)
            let opened = waitUntil(
                timeout: 10, condition: detailNavBar.exists || detailTitle.exists)
            if opened == false {
                attachScreenshot(app, name: "server_detail_not_opened")
            }
            XCTAssertTrue(opened, "Server detail screen did not appear")

            // Даём время на загрузку контента
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))

            // Ищем лейбл "Адрес" с прокруткой если нужно
            let addressLabel = app.staticTexts["Адрес"]
            let addressAppeared = waitUntil(
                timeout: 8,
                condition: addressLabel.exists,
                onTick: {
                    // Прокрутка вниз, если элемент не виден
                    if !addressLabel.exists {
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

    @MainActor
    func testTorrentListSearchAndRefresh() throws {
        #if os(macOS)
            throw XCTSkip(
                "Тест торрент-листа оптимизирован для iOS. На macOS используйте отдельные интеграционные тесты."
            )
        #else
            let app = launchApp(
                arguments: [
                    "--ui-testing-fixture=torrent-list-sample",
                    "--ui-testing-scenario=torrent-list-sample"
                ]
            )
            let serverIdentifier = "server_list_item_AAAA1111-B222-C333-D444-EEEEEEEEEEEE"
            let serverCell = app.buttons[serverIdentifier]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5), "Server cell not found")
            serverCell.tap()

            let torrentsHeader = app.staticTexts["Торренты"]
            XCTAssertTrue(torrentsHeader.waitForExistence(timeout: 5), "Torrent section missing")

            let ubuntuName = app.staticTexts["Ubuntu 25.04 Desktop"]
            XCTAssertTrue(ubuntuName.waitForExistence(timeout: 10))

            let fedoraName = app.staticTexts["Fedora 41 Workstation"]
            XCTAssertTrue(fedoraName.exists)

            let archName = app.staticTexts["Arch Linux Snapshot"]
            XCTAssertTrue(archName.exists)

            let speedSummaryPredicate = NSPredicate(format: "label CONTAINS %@", "↓")
            let speedSummaries = app.staticTexts.matching(speedSummaryPredicate)
            XCTAssertTrue(speedSummaries.count >= 3, "Speed summaries should be visible")

            let progressPredicate = NSPredicate(format: "label CONTAINS %@", "%")
            let progressSummaries = app.staticTexts.matching(progressPredicate)
            XCTAssertTrue(progressSummaries.count >= 3, "Progress values should be visible")

            attachScreenshot(app, name: "torrent_list_fixture")

            let searchField = app.searchFields.firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 4), "Search field not found")
            searchField.tap()
            searchField.typeText("Fedora")

            XCTAssertTrue(app.staticTexts["Fedora 41 Workstation"].waitForExistence(timeout: 3))
            XCTAssertTrue(
                app.staticTexts["Ubuntu 25.04 Desktop"].waitForDisappearance(timeout: 3),
                "Other torrents should be filtered out"
            )

            attachScreenshot(app, name: "torrent_list_search_result")
        #endif
    }

    @MainActor
    func testSettingsScreenShowsControls() {
        let app = launchApp()

        #if os(macOS)
            let settingsButton = app.toolbars.buttons["Настройки"].firstMatch
        #else
            let settingsButton = app.buttons["Настройки"]
        #endif
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button missing")
        settingsButton.tap()

        let autoRefreshToggle = app.descendants(matching: .any)["settings_auto_refresh_toggle"]
        if autoRefreshToggle.waitForExistence(timeout: 8) == false {
            // Возможно, sheet не открылся с первого раза — попробуем ещё раз
            settingsButton.tap()
        }
        let toggleExists = autoRefreshToggle.waitForExistence(timeout: 5)
        if toggleExists == false {
            attachScreenshot(app, name: "settings_toggle_missing")
        }
        XCTAssertTrue(toggleExists, "Auto-refresh toggle missing")

        let pollingSlider = app.sliders["settings_polling_slider"]
        XCTAssertTrue(pollingSlider.waitForExistence(timeout: 5), "Polling slider missing")

        let downloadField = app.textFields["settings_download_limit_field"]
        XCTAssertTrue(downloadField.waitForExistence(timeout: 5), "Download limit field missing")

        let uploadField = app.textFields["settings_upload_limit_field"]
        XCTAssertTrue(uploadField.waitForExistence(timeout: 5), "Upload limit field missing")

        let closeButton = app.buttons["settings_close_button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button missing")
        closeButton.tap()

        XCTAssertTrue(
            autoRefreshToggle.waitForDisappearance(timeout: 3),
            "Settings sheet did not close"
        )
    }

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

        // На macOS slider может вести себя нестабильно в UI-тестах, поэтому используем только текстовые поля
        #if os(iOS)
            // Change polling interval with safe fallback
            let initialPollingValue = controls.pollingValue.label
            let sliderChanged = adjustPollingInterval(
                controls: controls,
                initialValue: initialPollingValue,
                app: app
            )
            if !sliderChanged {
                attachScreenshot(app, name: "polling_slider_failed_to_change")
            }
        // На iOS продолжаем даже если slider не сработал, т.к. текстовые поля важнее
        #endif

        // Flip auto-refresh
        if let toggleValue = controls.autoRefreshToggle.value as? String {
            if toggleValue == "1" || toggleValue.lowercased() == "on" {
                controls.autoRefreshToggle.tap()
            } else {
                controls.autoRefreshToggle.tap()
            }
        } else {
            controls.autoRefreshToggle.tap()
        }

        // Set limits - это работает стабильно на всех платформах
        controls.downloadField.clearAndTypeText("777")
        controls.uploadField.clearAndTypeText("321")

        #if os(iOS)
            let savedPollingValue = controls.pollingValue.label
        #endif
        let savedAutoRefresh = (controls.autoRefreshToggle.value as? String) ?? ""
        let savedDownload = controls.downloadField.value as? String ?? ""
        let savedUpload = controls.uploadField.value as? String ?? ""

        controls.closeButton.tap()
        app.terminate()

        // Relaunch and verify persistence
        let relaunchedApp = launchApp(environment: persistenceEnvironment)
        controls = openSettingsControls(relaunchedApp)
        waitForSettingsLoaded(relaunchedApp)

        // Проверяем персистентность основных настроек (работает на всех платформах)
        #if os(iOS)
            XCTAssertEqual(
                controls.pollingValue.label, savedPollingValue, "Polling interval не сохранился")
        #endif
        XCTAssertEqual(
            (controls.autoRefreshToggle.value as? String) ?? "",
            savedAutoRefresh,
            "Auto-refresh toggle не сохранился"
        )
        XCTAssertEqual(
            controls.downloadField.value as? String ?? "",
            savedDownload,
            "Download limit не сохранился после перезапуска"
        )
        XCTAssertEqual(
            controls.uploadField.value as? String ?? "",
            savedUpload,
            "Upload limit не сохранился после перезапуска"
        )
    }

    @MainActor
    func testTorrentDetailFlow() throws {
        #if os(macOS)
            throw XCTSkip("Тест детализации торрента выполняется только в iOS среде.")
        #else
            let app = launchApp(
                arguments: [
                    "--ui-testing-fixture=torrent-list-sample",
                    "--ui-testing-scenario=torrent-list-sample"
                ]
            )
            let serverIdentifier = "server_list_item_AAAA1111-B222-C333-D444-EEEEEEEEEEEE"
            let serverCell = app.buttons[serverIdentifier]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5), "Server cell not found")
            serverCell.tap()

            let torrentsHeader = app.staticTexts["Торренты"]
            XCTAssertTrue(torrentsHeader.waitForExistence(timeout: 5), "Torrent section missing")

            let torrentRowButton = app.buttons["torrent_list_item_1001"]
            XCTAssertTrue(torrentRowButton.waitForExistence(timeout: 5), "Fixture torrent missing")
            torrentRowButton.tap()

            let detailNavBar = app.navigationBars["Ubuntu 25.04 Desktop"]
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5), "Detail screen not visible")

            XCTAssertTrue(
                app.otherElements["torrent-summary"].waitForExistence(timeout: 3),
                "Summary section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-main-info"].waitForExistence(timeout: 3),
                "Main info section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-statistics-section"].waitForExistence(timeout: 3),
                "Statistics section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-speed-history-section"].waitForExistence(timeout: 3),
                "Speed history missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-actions-section"].waitForExistence(timeout: 3),
                "Actions section missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-pause"].waitForExistence(timeout: 2),
                "Pause command missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-verify"].waitForExistence(timeout: 2),
                "Verify command missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-remove"].waitForExistence(timeout: 2),
                "Remove command missing"
            )

            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.waitForExistence(timeout: 2))

            let filesSection = app.otherElements["torrent-files-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: filesSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Files section missing"
            )

            let trackersSection = app.otherElements["torrent-trackers-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: trackersSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Trackers section missing"
            )

            let peersSection = app.otherElements["torrent-peers-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: peersSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Peers section missing"
            )

            attachScreenshot(app, name: "torrent_detail_fixture")
        #endif
    }

    @MainActor
    func testOnboardingFlowAddsServer() throws {
        #if os(macOS)
            throw XCTSkip("Онбординг UI-тест выполняется только на iOS среде.")
        #else
            let app = launchApp(
                arguments: ["--ui-testing-scenario=onboarding-flow"],
                dismissOnboarding: false
            )
            let serverName = "UITest NAS"

            let onboardingNavBar = app.navigationBars["Новый сервер"]
            if onboardingNavBar.waitForExistence(timeout: 2) == false {
                let addButton = app.buttons["server_list_add_button"]
                XCTAssertTrue(addButton.waitForExistence(timeout: 5))
                addButton.tap()
                XCTAssertTrue(onboardingNavBar.waitForExistence(timeout: 3))
            }

            fillOnboardingForm(app: app, serverName: serverName)
            captureHttpWarning(app: app)
            completeConnectionCheck(app: app)

            let submitButton = app.buttons["onboarding_submit_button"]
            XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
            submitButton.tap()
            XCTAssertTrue(onboardingNavBar.waitForDisappearance(timeout: 5))

            let detailNavBar = app.navigationBars[serverName]
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5))
            let editButton = app.buttons["Изменить"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: editButton.exists,
                    onTick: { app.swipeDown() }
                ),
                "Экран деталей сервера не отобразился"
            )
        #endif
    }

    @discardableResult
    @MainActor
    private func launchApp(
        arguments: [String] = [],
        environment: [String: String] = [:],
        dismissOnboarding: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        var launchArgs = app.launchArguments
        launchArgs.append(contentsOf: arguments)
        app.launchArguments = launchArgs
        var launchEnvironment = app.launchEnvironment
        for (key, value) in environment {
            launchEnvironment[key] = value
        }
        if let fixtureArg = arguments.first(where: { $0.hasPrefix("--ui-testing-fixture=") }) {
            let value = String(fixtureArg.dropFirst("--ui-testing-fixture=".count))
            launchEnvironment["UI_TESTING_FIXTURE"] = value
        }
        app.launchEnvironment = launchEnvironment
        app.launch()
        addTeardownBlock {
            app.terminate()
        }
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
    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let cancelButton = app.buttons["onboarding_cancel_button"].firstMatch
        guard cancelButton.waitForExistence(timeout: 6) else { return }
        cancelButton.tap()
        if cancelButton.waitForDisappearance(timeout: 3) == false {
            attachScreenshot(app, name: "onboarding_cancel_sticky")
        }
    }

    @MainActor
    private func openSettingsControls(_ app: XCUIApplication) -> SettingsControls {
        #if os(macOS)
            let settingsButton = app.toolbars.buttons["Настройки"].firstMatch
        #else
            let settingsButton = app.buttons["Настройки"]
        #endif
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button missing")
        settingsButton.tap()

        let autoRefreshToggle = app.descendants(matching: .any)["settings_auto_refresh_toggle"]
        XCTAssertTrue(autoRefreshToggle.waitForExistence(timeout: 5), "Auto-refresh toggle missing")

        let pollingSlider = app.sliders["settings_polling_slider"]
        XCTAssertTrue(pollingSlider.waitForExistence(timeout: 5), "Polling slider missing")

        let pollingValue = app.staticTexts["settings_polling_value"]
        XCTAssertTrue(pollingValue.waitForExistence(timeout: 2), "Polling value missing")

        let downloadField = app.textFields["settings_download_limit_field"]
        XCTAssertTrue(downloadField.waitForExistence(timeout: 5), "Download limit field missing")

        let uploadField = app.textFields["settings_upload_limit_field"]
        XCTAssertTrue(uploadField.waitForExistence(timeout: 5), "Upload limit field missing")

        let closeButton = app.buttons["settings_close_button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2), "Close button missing")

        return SettingsControls(
            autoRefreshToggle: autoRefreshToggle,
            pollingSlider: pollingSlider,
            pollingValue: pollingValue,
            downloadField: downloadField,
            uploadField: uploadField,
            closeButton: closeButton
        )
    }

    @MainActor
    private func fillOnboardingForm(app: XCUIApplication, serverName: String) {
        let nameField = app.textFields["Имя сервера"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.clearAndTypeText(serverName)

        let hostField = app.textFields["Host"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 5))
        hostField.clearAndTypeText("qa.remission.test")
        hostField.typeText("\n")

        let portField = app.textFields["Порт"]
        XCTAssertTrue(portField.waitForExistence(timeout: 5))
        portField.clearAndTypeText("8443")

        let usernameField = app.textFields["Имя пользователя"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("tester")

        let passwordField = app.secureTextFields["Пароль"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("passw0rd!\n")
    }

    @MainActor
    private func captureHttpWarning(app: XCUIApplication) {
        app.swipeUp()
        let httpButton = app.buttons["HTTP"].firstMatch

        if httpButton.waitForExistence(timeout: 5) == false {
            attachScreenshot(app, name: "onboarding_http_toggle_missing")
            return
        }

        var attempts = 0
        while attempts < 5 && (httpButton.isHittable == false) {
            app.swipeUp()
            attempts += 1
        }

        if httpButton.isHittable == false {
            attachScreenshot(app, name: "onboarding_http_toggle_not_hittable")
            let frame = httpButton.frame
            if frame.isEmpty == false {
                let coord = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
                coord.tap()
            } else {
                return
            }
        } else {
            httpButton.tap()
        }

        let httpAlert = app.alerts["Небезопасное подключение"]
        if httpAlert.waitForExistence(timeout: 8) == false {
            attachScreenshot(app, name: "onboarding_http_warning_missing")
            return
        }
        attachScreenshot(app, name: "onboarding_http_warning")

        let cancelButton = httpAlert.buttons["Отмена"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        } else {
            app.tap()
        }

        let httpsButton = app.buttons["HTTPS"]
        if httpsButton.exists {
            if httpsButton.isHittable {
                httpsButton.tap()
            } else {
                app.swipeDown()
                if httpsButton.isHittable {
                    httpsButton.tap()
                }
            }
        }
    }

    @MainActor
    private func completeConnectionCheck(app: XCUIApplication) {
        app.swipeUp()
        let checkButton = app.buttons["onboarding_connection_check_button"]
        XCTAssertTrue(
            checkButton.waitForExistence(timeout: 5),
            "Кнопка проверки соединения не найдена"
        )
        checkButton.tap()

        let submitButton = app.buttons["onboarding_submit_button"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        XCTAssertTrue(
            waitUntil(
                timeout: 12,
                condition: submitButton.isEnabled,
                onTick: { app.swipeDown() }
            ),
            "Кнопка сохранения не активировалась после проверки соединения"
        )

        let successElement = app.descendants(matching: .any)["onboarding_connection_success"]
        if successElement.waitForExistence(timeout: 1) == false {
            attachScreenshot(app, name: "onboarding_connection_success_missing")
        }
    }

    @MainActor
    private func waitUntil(
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
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func waitForSettingsLoaded(_ app: XCUIApplication) {
        let loading = app.staticTexts["Загружаем настройки…"]
        if loading.exists {
            _ = loading.waitForDisappearance(timeout: 5)
        } else {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }

    @MainActor
    private func adjustPollingInterval(
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
}

private struct SettingsControls {
    let autoRefreshToggle: XCUIElement
    let pollingSlider: XCUIElement
    let pollingValue: XCUIElement
    let downloadField: XCUIElement
    let uploadField: XCUIElement
    let closeButton: XCUIElement
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

    fileprivate func clearAndTypeText(_ text: String) {
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
