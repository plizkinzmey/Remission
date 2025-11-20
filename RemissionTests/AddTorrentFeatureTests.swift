import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AddTorrentFeatureTests {
    @Test
    func submitMagnetAddsTorrentWithParameters() async {
        let captured = LockedValue<(PendingTorrentInput, String, Bool, [String]?)?>(nil)
        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: .init(rawValue: 42),
            name: "Demo torrent",
            hashString: "deadbeef"
        )

        let repository = TorrentRepository.test(
            add: { input, destination, startPaused, tags in
                captured.withValue { $0 = (input, destination, startPaused, tags) }
                return addResult
            }
        )

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: environment,
                destinationPath: "/downloads",
                startPaused: true,
                tags: ["linux"]
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(
            .submitResponse(
                .success(.init(addResult: addResult))
            )
        ) {
            $0.isSubmitting = false
            $0.closeOnAlertDismiss = true
            $0.alert = AlertState {
                TextState("Торрент добавлен")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Добавлен торрент Demo torrent")
            }
        }
        await store.send(.alert(.presented(.dismiss))) {
            $0.alert = nil
            $0.closeOnAlertDismiss = false
        }
        await store.receive(.delegate(.closeRequested))

        let capturedValue = captured.value
        #expect(capturedValue?.0.displayName == "magnet:?xt=urn:btih:demo")
        #expect(capturedValue?.1 == "/downloads")
        #expect(capturedValue?.2 == true)
        #expect(capturedValue?.3 == ["linux"])
    }

    @Test
    func duplicateTorrentShowsInfoAlertAndCloses() async {
        let addResult = TorrentRepository.AddResult(
            status: .duplicate,
            id: .init(rawValue: 7),
            name: "Existing Torrent",
            hashString: "duplicate-hash"
        )

        let repository = TorrentRepository.test(
            add: { _, destination, _, _ in
                #expect(destination == "/downloads")
                return addResult
            }
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:duplicate")!,
                        rawValue: "magnet:?xt=urn:btih:duplicate"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: .testEnvironment(
                    server: .previewLocalHTTP,
                    torrentRepository: repository
                ),
                destinationPath: "/downloads"
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(
            .submitResponse(
                .success(.init(addResult: addResult))
            )
        ) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState("Торрент уже добавлен")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Переданный торрент уже есть в списке: Existing Torrent")
            }
            $0.closeOnAlertDismiss = true
        }
        await store.send(.alert(.presented(.dismiss))) {
            $0.alert = nil
            $0.closeOnAlertDismiss = false
        }
        await store.receive(.delegate(.closeRequested))
    }

    @Test
    func unauthorizedErrorShowsAlertWithoutClosing() async {
        let repository = TorrentRepository.test(
            add: { _, _, _, _ in
                throw APIError.unauthorized
            }
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: .testEnvironment(
                    server: .previewLocalHTTP,
                    torrentRepository: repository
                ),
                destinationPath: "/downloads"
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(.submitResponse(.failure(.unauthorized))) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState("Не удалось добавить торрент")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Проверьте логин/пароль и повторите попытку.")
            }
            $0.closeOnAlertDismiss = false
        }
        await store.send(.alert(.presented(.dismiss))) {
            $0.alert = nil
        }
    }

    @Test
    func emptyDestinationShowsAlert() async {
        let environment = ServerConnectionEnvironment.preview(server: .previewLocalHTTP)
        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: environment,
                destinationPath: "   "
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.alert = AlertState {
                TextState("Укажите каталог загрузки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Поле каталога загрузки не может быть пустым.")
            }
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&_value)
        lock.unlock()
    }
}
