import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

private struct CapturedAddParams: Sendable {
    var input: PendingTorrentInput
    var destination: String
    var startPaused: Bool
    var tags: [String]?
}

@MainActor
struct AddTorrentFeatureTests {}

extension AddTorrentFeatureTests {
    @Test
    // swiftlint:disable:next function_body_length
    func submitMagnetAddsTorrentWithParameters() async {
        let captured = LockedValue<CapturedAddParams?>(nil)
        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: .init(rawValue: 42),
            name: "Demo torrent",
            hashString: "deadbeef"
        )

        let repository = TorrentRepository.test(
            add: { input, destination, startPaused, tags in
                captured.withValue {
                    $0 = CapturedAddParams(
                        input: input,
                        destination: destination,
                        startPaused: startPaused,
                        tags: tags
                    )
                }
                return addResult
            }
        )

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        let store = TestStore(
            initialState: {
                var state = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:demo")!,
                            rawValue: "magnet:?xt=urn:btih:demo"
                        ),
                        sourceDescription: "Magnet"
                    ),
                    connectionEnvironment: environment
                )
                state.destinationPath = "/downloads"
                state.startPaused = true
                state.tags = ["linux"]
                return state
            }()
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
                TextState(L10n.tr("torrentAdd.alert.added.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(
                    String(
                        format: L10n.tr("torrentAdd.alert.added.message"),
                        addResult.name
                    )
                )
            }
        }
        await store.receive(.delegate(.addCompleted(addResult)))
        await store.send(.alert(.presented(.dismiss))) {
            $0.alert = nil
            $0.closeOnAlertDismiss = false
        }
        await store.receive(.delegate(.closeRequested))

        let capturedValue = captured.value
        #expect(capturedValue?.input.displayName == "magnet:?xt=urn:btih:demo")
        #expect(capturedValue?.destination == "/downloads")
        #expect(capturedValue?.startPaused == true)
        #expect(capturedValue?.tags == ["linux"])
    }

    @Test
    // swiftlint:disable:next function_body_length
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
            initialState: {
                var state = AddTorrentReducer.State(
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
                    )
                )
                state.destinationPath = "/downloads"
                return state
            }()
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
                TextState(L10n.tr("torrentAdd.alert.duplicate.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(
                    String(
                        format: L10n.tr("torrentAdd.alert.duplicate.message"),
                        addResult.name
                    )
                )
            }
            $0.closeOnAlertDismiss = true
        }
        await store.receive(.delegate(.addCompleted(addResult)))
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
            initialState: {
                var state = AddTorrentReducer.State(
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
                    )
                )
                state.destinationPath = "/downloads"
                return state
            }()
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
                TextState(L10n.tr("torrentAdd.alert.addFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(AddTorrentReducer.SubmitError.unauthorized.message)
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
            initialState: {
                var state = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:demo")!,
                            rawValue: "magnet:?xt=urn:btih:demo"
                        ),
                        sourceDescription: "Magnet"
                    ),
                    connectionEnvironment: environment
                )
                state.destinationPath = "   "
                return state
            }()
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.destinationRequired.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("torrentAdd.alert.destinationRequired.message"))
            }
        }
    }

    @Test
    func sessionConflictShowsAlert() async {
        let repository = TorrentRepository.test(
            add: { _, _, _, _ in
                throw APIError.sessionConflict
            }
        )

        let store = TestStore(
            initialState: {
                var state = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:conflict")!,
                            rawValue: "magnet:?xt=urn:btih:conflict"
                        ),
                        sourceDescription: "Magnet"
                    ),
                    connectionEnvironment: .testEnvironment(
                        server: .previewLocalHTTP,
                        torrentRepository: repository
                    )
                )
                state.destinationPath = "/downloads"
                return state
            }()
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(.submitResponse(.failure(.sessionConflict))) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.addFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(AddTorrentReducer.SubmitError.sessionConflict.message)
            }
            $0.closeOnAlertDismiss = false
        }
    }

    @Test
    func mappingErrorShowsAlert() async {
        let mappingError = DomainMappingError.invalidValue(
            field: "result",
            description: "unexpected value",
            context: "torrent-add"
        )
        let repository = TorrentRepository.test(
            add: { _, _, _, _ in
                throw mappingError
            }
        )

        let store = TestStore(
            initialState: {
                var state = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:mapping")!,
                            rawValue: "magnet:?xt=urn:btih:mapping"
                        ),
                        sourceDescription: "Magnet"
                    ),
                    connectionEnvironment: .testEnvironment(
                        server: .previewLocalHTTP,
                        torrentRepository: repository
                    )
                )
                state.destinationPath = "/downloads"
                return state
            }()
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(
            .submitResponse(.failure(.mapping(mappingError.localizedDescription)))
        ) {
            $0.isSubmitting = false
            $0.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.addFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(
                    AddTorrentReducer.SubmitError.mapping(mappingError.localizedDescription).message
                )
            }
            $0.closeOnAlertDismiss = false
        }
    }

    @Test
    func missingConnectionEnvironmentShowsAlert() async {
        let store = TestStore(
            initialState: {
                var state = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:noenv")!,
                            rawValue: "magnet:?xt=urn:btih:noenv"
                        ),
                        sourceDescription: "Magnet"
                    )
                )
                state.connectionEnvironment = nil
                state.destinationPath = "/downloads"
                return state
            }()
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.noConnection.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("torrentAdd.alert.noConnection.message"))
            }
            $0.closeOnAlertDismiss = false
            $0.isSubmitting = false
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
