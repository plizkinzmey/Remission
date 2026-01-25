import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ErrorPresenterTests {
    private enum Retry: Equatable, Sendable {
        case reload
        case reconnect
    }

    // Проверяет, что показ баннера заполняет состояние баннера сообщением и retry-действием.
    @Test
    func showBannerSetsBannerState() async {
        let store = TestStore(initialState: ErrorPresenter<Retry>.State()) {
            ErrorPresenter<Retry>()
        }

        await store.send(.showBanner(message: "Ошибка сети", retry: .reload)) {
            $0.banner = .init(message: "Ошибка сети", retry: .reload)
        }
    }

    // Проверяет, что ручное закрытие баннера очищает его из состояния.
    @Test
    func bannerDismissedClearsBanner() async {
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
    @Test
    func bannerRetryTappedWithRetryEmitsRetryRequested() async {
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
    @Test
    func bannerRetryTappedWithoutRetryOnlyClearsBanner() async {
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
    @Test
    func showAlertWithRetryConfiguresAlertAndPendingRetry() {
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

        #expect(state.pendingRetry == .reconnect)
        #expect(state.alert != nil)
        #expect(state.alert?.buttons.count == 2)
    }

    // Проверяет, что showAlert без retry не сохраняет pendingRetry и показывает только кнопку закрытия.
    @Test
    func showAlertWithoutRetryShowsOnlyDismissButton() {
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

        #expect(state.pendingRetry == nil)
        #expect(state.alert != nil)
        #expect(state.alert?.buttons.count == 1)
    }

    // Проверяет, что нажатие retry в алерте отправляет retryRequested и очищает alert/pendingRetry.
    @Test
    func alertRetryPresentedEmitsRetryRequestedAndClearsState() async {
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
    @Test
    func alertRetryPresentedWithoutPendingRetryOnlyDismissesAlert() async {
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
    @Test
    func alertDismissPresentedClearsAlertAndPendingRetry() async {
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
