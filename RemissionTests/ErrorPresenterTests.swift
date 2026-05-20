import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class ErrorPresenterTests: XCTestCase {
    private enum Retry: Equatable, Sendable {
        case reload
        case reconnect
    }

    // Проверяет, что показ баннера заполняет состояние баннера сообщением и retry-действием.
    func testShowBannerSetsBannerState() async {
        await withMainSerialExecutor {
            let store = TestStore(initialState: ErrorPresenter<Retry>.State()) {
                ErrorPresenter<Retry>()
            }

            await store.send(.showBanner(message: "Ошибка сети", retry: .reload)) {
                $0.banner = .init(message: "Ошибка сети", retry: .reload)
            }
        }
    }

    // Проверяет, что ручное закрытие баннера очищает его из состояния.
    func testBannerDismissedClearsBanner() async {
        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(
                banner: .init(message: "Ошибка", retry: .reload)
            )
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.bannerDismissed) {
            $0.banner = nil
        }
    }

    // Проверяет, что нажатие retry в баннере отправляет retryRequested и очищает баннер.
    func testBannerRetryTappedWithRetryEmitsRetryRequested() async {
        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(
                banner: .init(message: "Ошибка", retry: .reload)
            )
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.bannerRetryTapped) {
            $0.banner = nil
        }
        await store.receive(.retryRequested(.reload))
    }

    // Проверяет, что если retry отсутствует, баннер просто скрывается без побочных эффектов.
    func testBannerRetryTappedWithoutRetryOnlyClearsBanner() async {
        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(
                banner: .init(message: "Ошибка", retry: nil)
            )
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.bannerRetryTapped) {
            $0.banner = nil
        }
    }

    // Проверяет, что showAlert с retry сохраняет pendingRetry и добавляет кнопку retry в алерт.
    func testShowAlertWithRetryConfiguresAlertAndPendingRetry() {
        var state = ErrorPresenter<Retry>.State()
        let reducer = ErrorPresenter<Retry>()

        _ = reducer.reduce(
            into: &state,
            action: .showAlert(
                title: "Ошибка",
                message: "Попробовать снова?",
                retry: .reconnect
            )
        )

        XCTAssertEqual(state.pendingRetry, .reconnect)
        XCTAssertNotNil(state.alert)
        XCTAssertEqual(state.alert?.buttons.count, 2)
    }

    // Проверяет, что showAlert без retry не сохраняет pendingRetry и показывает только кнопку закрытия.
    func testShowAlertWithoutRetryShowsOnlyDismissButton() {
        var state = ErrorPresenter<Retry>.State()
        let reducer = ErrorPresenter<Retry>()

        _ = reducer.reduce(
            into: &state,
            action: .showAlert(
                title: "Ошибка",
                message: "Без повторной попытки",
                retry: nil
            )
        )

        XCTAssertNil(state.pendingRetry)
        XCTAssertNotNil(state.alert)
        XCTAssertEqual(state.alert?.buttons.count, 1)
    }

    // Проверяет, что нажатие retry в алерте отправляет retryRequested и очищает alert/pendingRetry.
    func testAlertRetryPresentedEmitsRetryRequestedAndClearsState() async {
        let initialAlert = AlertState<ErrorPresenter<Retry>.AlertAction> {
            TextState("Ошибка")
        }

        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(
                banner: nil,
                alert: initialAlert,
                pendingRetry: .reload
            )
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.alert(.presented(.retry))) {
            $0.pendingRetry = nil
            $0.alert = nil
        }
        await store.receive(.retryRequested(.reload))
    }

    // Проверяет, что retry в алерте без pendingRetry просто закрывает алерт.
    func testAlertRetryPresentedWithoutPendingRetryOnlyDismissesAlert() async {
        let initialAlert = AlertState<ErrorPresenter<Retry>.AlertAction> {
            TextState("Ошибка")
        }

        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(alert: initialAlert)
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.alert(.presented(.retry))) {
            $0.alert = nil
        }
    }

    // Проверяет, что dismiss в алерте очищает и alert, и pendingRetry.
    func testAlertDismissPresentedClearsAlertAndPendingRetry() async {
        let initialAlert = AlertState<ErrorPresenter<Retry>.AlertAction> {
            TextState("Ошибка")
        }

        let store = TestStore(
            initialState: ErrorPresenter<Retry>.State(
                banner: nil,
                alert: initialAlert,
                pendingRetry: .reconnect
            )
        ) {
            ErrorPresenter<Retry>()
        }

        await store.send(.alert(.presented(.dismiss))) {
            $0.pendingRetry = nil
            $0.alert = nil
        }
    }
}
