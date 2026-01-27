import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Configuration Reducer Tests")
@MainActor
struct ServerConfigurationReducerTests {

    @Test("Binding фильтрует значения формы")
    func testBindingFiltersInputs() async {
        // Проверяем, что binding удаляет символы, не подходящие под правила ввода.
        let store = TestStore(initialState: ServerConfigurationReducer.State()) {
            ServerConfigurationReducer()
        }
        store.exhaustivity = .off

        await store.send(.binding(.set(\.form.name, "Test!@#"))) {
            $0.form.name = "Test"
        }

        await store.send(.binding(.set(\.form.host, "ex ample.com"))) {
            $0.form.host = "example.com"
        }

        await store.send(.binding(.set(\.form.port, "80a91"))) {
            $0.form.port = "8091"
        }

        await store.send(.binding(.set(\.form.path, " /trans mission/rpc "))) {
            $0.form.path = "/transmission/rpc"
        }

        await store.send(.binding(.set(\.form.username, "user name"))) {
            $0.form.username = "username"
        }

        await store.send(.binding(.set(\.form.password, "pa ss"))) {
            $0.form.password = "pass"
        }
    }

    @Test("Проверка соединения без валидной формы даёт ошибку")
    func testCheckConnectionInvalidForm() async {
        // Проверяем, что при пустом host выставляется validationError и не запускается probe.
        var state = ServerConfigurationReducer.State()
        state.form.host = ""
        state.form.port = "9091"

        let store = TestStore(initialState: state) {
            ServerConfigurationReducer()
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.validationError = L10n.tr("onboarding.error.validation.hostPort")
        }
    }

    @Test("UI тест обхода соединения возвращает verifiedSubmission")
    func testUiTestBypassConnection() async {
        // Проверяем, что uiTestBypassConnection помечает соединение успешным и сообщает delegate.
        var state = ServerConfigurationReducer.State()
        state.form.host = "nas.local"
        state.form.port = "9091"

        let store = TestStore(initialState: state) {
            ServerConfigurationReducer()
        }

        await store.send(.uiTestBypassConnection) {
            $0.connectionStatus = .success(.uiTestPlaceholder)
            #expect($0.verifiedSubmission != nil)
        }

        if let context = store.state.verifiedSubmission {
            await store.receive(.delegate(.connectionVerified(context)))
        }
    }

    @Test("Успешная проверка соединения сообщает delegate")
    func testConnectionTestFinishedSuccess() async {
        // Проверяем, что успешный результат пробрасывает verifiedSubmission в delegate.
        let server = ServerConfig.previewLocalHTTP
        let context = ServerSubmissionContext(server: server, password: "secret")
        let handshake = TransmissionHandshakeResult(
            sessionID: "session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.0",
            isCompatible: true
        )

        var state = ServerConfigurationReducer.State()
        state.verifiedSubmission = context
        state.connectionStatus = .testing

        let store = TestStore(initialState: state) {
            ServerConfigurationReducer()
        }

        await store.send(.connectionTestFinished(.success(handshake))) {
            $0.connectionStatus = .success(handshake)
        }

        await store.receive(.delegate(.connectionVerified(context)))
    }

    @Test("Неуспешная проверка соединения очищает verifiedSubmission")
    func testConnectionTestFinishedFailure() async {
        // Проверяем, что ошибка сбрасывает verifiedSubmission и фиксируется в статусе.
        let server = ServerConfig.previewLocalHTTP
        let context = ServerSubmissionContext(server: server, password: "secret")

        var state = ServerConfigurationReducer.State()
        state.verifiedSubmission = context
        state.connectionStatus = .testing

        let store = TestStore(initialState: state) {
            ServerConfigurationReducer()
        }

        await store.send(.connectionTestFinished(.failure("fail"))) {
            $0.connectionStatus = .failed("fail")
            $0.verifiedSubmission = nil
        }
    }
}
