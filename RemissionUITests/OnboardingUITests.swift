import XCTest

@MainActor
final class OnboardingUITests: BaseUITestCase {

    func testOnboardingFlowAddsServer() throws {
        #if os(macOS)
            throw XCTSkip("Онбординг UI-тест выполняется только на iOS среде.")
        #else
            let app = launchApp(
                arguments: ["--ui-testing-scenario=onboarding-flow"],
                dismissOnboarding: false
            )
            let serverName = "UITest NAS"

            let onboardingNavBar = navigationBar(app, titles: ["Новый сервер", "New server"])
            if onboardingNavBar?.waitForExistence(timeout: 2) == false {
                let addButton = app.buttons["server_list_add_button"]
                XCTAssertTrue(addButton.waitForExistence(timeout: 5))
                addButton.tap()
                XCTAssertTrue(
                    navigationBar(app, titles: ["Новый сервер", "New server"])?
                        .waitForExistence(timeout: 3) == true
                )
            }

            fillOnboardingForm(app: app, serverName: serverName)
            captureHttpWarning(app: app)
            completeConnectionCheck(app: app)

            let submitButton = app.buttons["onboarding_submit_button"]
            XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
            submitButton.tap()
            XCTAssertTrue(onboardingNavBar?.waitForDisappearance(timeout: 5) == true)

            let detailNavBar = app.navigationBars[serverName]
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5))
            let editButton = firstExistingButton(app, labels: ["Изменить", "Change"])
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: editButton?.exists == true,
                    onTick: { app.swipeDown() }
                ),
                "Экран деталей сервера не отобразился"
            )
        #endif
    }

    // MARK: - Private Helpers

    private func fillOnboardingForm(app: XCUIApplication, serverName: String) {
        let nameField = firstExistingTextField(app, labels: ["Имя сервера", "Server name"])
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.clearAndTypeText(serverName)

        let hostField = app.textFields["Host"]
        XCTAssertTrue(hostField.waitForExistence(timeout: 5))
        hostField.clearAndTypeText("qa.remission.test")
        hostField.typeText("\n")

        let portField = firstExistingTextField(app, labels: ["Порт", "Port"])
        XCTAssertTrue(portField.waitForExistence(timeout: 5))
        portField.clearAndTypeText("8443")

        let usernameField = firstExistingTextField(app, labels: ["Имя пользователя", "Username"])
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("tester")

        let passwordField = firstExistingSecureField(app, labels: ["Пароль", "Password"])
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("passw0rd!\n")
    }

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

        let httpAlert = firstExistingAlert(
            app, titles: ["Небезопасное подключение", "Insecure connection"])
        if httpAlert?.waitForExistence(timeout: 8) == false {
            attachScreenshot(app, name: "onboarding_http_warning_missing")
            return
        }
        attachScreenshot(app, name: "onboarding_http_warning")

        // Ищем Cancel только в алерте, не во всём app, чтобы не нажать Cancel онбординга
        guard let alert = httpAlert else { return }
        let cancelButton = firstExistingButton(alert, labels: ["Отмена", "Cancel"])
        if cancelButton?.waitForExistence(timeout: 2) == true {
            cancelButton?.tap()
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

    private func completeConnectionCheck(app: XCUIApplication) {
        var checkButton = app.buttons["onboarding_connection_check_button"].firstMatch

        if checkButton.exists == false {
            checkButton =
                app.descendants(matching: .any)["onboarding_connection_check_button"].firstMatch
        }

        let appeared = waitUntil(
            timeout: 10,
            condition: checkButton.exists,
            onTick: {
                if checkButton.exists == false {
                    app.swipeUp()
                }
            }
        )
        if appeared == false {
            attachScreenshot(app, name: "onboarding_check_button_not_found")
        }
        XCTAssertTrue(appeared, "Кнопка проверки соединения не найдена")
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

    // MARK: - Localization Helpers

    private func navigationBar(_ app: XCUIApplication, titles: [String]) -> XCUIElement? {
        for title in titles {
            let bar = app.navigationBars[title]
            if bar.exists { return bar }
        }
        return titles.compactMap { app.navigationBars[$0] }.first
    }

    private func firstExistingTextField(_ app: XCUIApplication, labels: [String]) -> XCUIElement {
        for label in labels {
            let field = app.textFields[label]
            if field.exists { return field }
        }
        return app.textFields.firstMatch
    }

    private func firstExistingSecureField(_ app: XCUIApplication, labels: [String]) -> XCUIElement {
        for label in labels {
            let field = app.secureTextFields[label]
            if field.exists { return field }
        }
        return app.secureTextFields.firstMatch
    }

    private func firstExistingButton(_ container: XCUIElement, labels: [String]) -> XCUIElement? {
        for label in labels {
            let button = container.buttons[label]
            if button.exists { return button }
        }
        return nil
    }

    private func firstExistingAlert(
        _ app: XCUIApplication,
        titles: [String]
    ) -> XCUIElement? {
        for title in titles {
            let alert = app.alerts[title]
            if alert.exists { return alert }
        }
        return nil
    }
}
