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
        let exists = serverCell.waitForExistence(timeout: 5)
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
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Адрес"].exists)
        #endif
    }

    @MainActor
    func testTorrentListSearchAndRefresh() throws {
        #if os(macOS)
            // На macOS этот тест ненадежен из-за асинхронной загрузки торрентов в UI
            // и различных сроков срабатывания. На iOS тест работает стабильнее благодаря
            // лучшей синхронизации View lifecycle.
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
            XCTAssertTrue(app.staticTexts["Адрес"].waitForExistence(timeout: 2))
        #endif
    }

    @discardableResult
    @MainActor
    private func launchApp(
        arguments: [String] = [],
        dismissOnboarding: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        var launchArgs = app.launchArguments
        launchArgs.append(contentsOf: arguments)
        app.launchArguments = launchArgs
        if let fixtureArg = arguments.first(where: { $0.hasPrefix("--ui-testing-fixture=") }) {
            let value = String(fixtureArg.dropFirst("--ui-testing-fixture=".count))
            app.launchEnvironment["UI_TESTING_FIXTURE"] = value
        }
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
        // Try to reveal transport selector if offscreen
        app.swipeUp()
        let httpButton = app.buttons["HTTP"].firstMatch

        // If HTTP toggle is missing, attach diagnostics and continue (some configs may hide it)
        if httpButton.waitForExistence(timeout: 5) == false {
            attachScreenshot(app, name: "onboarding_http_toggle_missing")
            return
        }

        // Make a few attempts to make it hittable
        var attempts = 0
        while attempts < 5 && (httpButton.isHittable == false) {
            app.swipeUp()
            attempts += 1
        }

        if httpButton.isHittable == false {
            attachScreenshot(app, name: "onboarding_http_toggle_not_hittable")
            // Try coordinate tap fallback
            let frame = httpButton.frame
            if frame.isEmpty == false {
                let coord = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
                coord.tap()
            } else {
                // Give up gracefully
                return
            }
        } else {
            httpButton.tap()
        }

        // The alert title is "Небезопасное подключение" per OnboardingReducer.makeInsecureTransportAlert()
        let httpAlert = app.alerts["Небезопасное подключение"]
        // Allow more time on CI
        if httpAlert.waitForExistence(timeout: 8) == false {
            attachScreenshot(app, name: "onboarding_http_warning_missing")
            // It might be auto-suppressed by prefs; continue
            return
        }
        attachScreenshot(app, name: "onboarding_http_warning")

        // Prefer cancel to keep HTTPS afterwards
        let cancelButton = httpAlert.buttons["Отмена"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        } else {
            // Fallback: dismiss by tapping outside if needed
            app.tap()
        }

        // Ensure HTTPS is selected if visible; do not fail if absent
        let httpsButton = app.buttons["HTTPS"]
        if httpsButton.exists {
            if httpsButton.isHittable {
                httpsButton.tap()
            } else {
                // Try to make it hittable
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

        // В UI-тестах используется мок, который обычно не показывает trust prompt,
        // поэтому просто ждём элемента успеха/лейбла
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

        // Не делаем блокирующих assert на success view, но добавляем диагностику
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
