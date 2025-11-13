import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length type_body_length

@MainActor
struct ServerDetailFeatureTests {
    @Test
    func taskInitializesConnectionEnvironment() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session-1",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake
        )

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
        }

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }

        await store.receive(
            .connectionResponse(
                .success(
                    ServerDetailReducer.ConnectionResponse(
                        environment: environment,
                        handshake: handshake
                    )
                )
            )
        ) {
            $0.connectionEnvironment = environment
            $0.connectionState.phase = .ready(
                .init(fingerprint: environment.fingerprint, handshake: handshake)
            )
        }
        await store.receive(.torrentList(.connectionAvailable(environment))) {
            $0.torrentList.connectionEnvironment = environment
            $0.torrentList.isLoading = true
            $0.torrentList.errorMessage = nil
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.isLoading = false
            $0.torrentList.torrents = []
        }
    }

    @Test
    func connectionFailureShowsAlert() async {
        let server = ServerConfig.previewSecureSeedbox
        let expectedError = ServerConnectionEnvironmentFactoryError.missingCredentials

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .init { _ in
                throw expectedError
            }
        }

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }

        await store.receive(.connectionResponse(.failure(expectedError))) {
            $0.connectionEnvironment = nil
            $0.connectionState.phase = .failed(.init(message: expectedError.errorDescription ?? ""))
            $0.alert = .connectionFailure(message: expectedError.errorDescription ?? "")
        }
    }

    @Test
    func serverUpdateReinitializesConnection() async {
        var initialServer = ServerConfig.previewLocalHTTP
        initialServer.name = "NAS"
        var updatedServer = initialServer
        updatedServer.connection = .init(host: "updated-nas.local", port: 9091)

        let firstHandshake = TransmissionHandshakeResult(
            sessionID: "first",
            rpcVersion: 19,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0",
            isCompatible: true
        )
        let secondHandshake = TransmissionHandshakeResult(
            sessionID: "second",
            rpcVersion: 21,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.1",
            isCompatible: true
        )

        let firstEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: initialServer,
            handshake: firstHandshake
        )
        let secondEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: updatedServer,
            handshake: secondHandshake
        )

        let invocationCount = LockedValue(0)

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: initialServer)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .init { _ in
                let index = min(invocationCount.value, 1)
                invocationCount.withValue { $0 += 1 }
                return index == 0 ? firstEnvironment : secondEnvironment
            }
        }

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }

        await store.receive(
            .connectionResponse(
                .success(
                    ServerDetailReducer.ConnectionResponse(
                        environment: firstEnvironment,
                        handshake: firstHandshake
                    )
                )
            )
        ) {
            $0.connectionEnvironment = firstEnvironment
            $0.connectionState.phase = .ready(
                .init(fingerprint: firstEnvironment.fingerprint, handshake: firstHandshake)
            )
        }
        await store.receive(.torrentList(.connectionAvailable(firstEnvironment))) {
            $0.torrentList.connectionEnvironment = firstEnvironment
            $0.torrentList.isLoading = true
            $0.torrentList.errorMessage = nil
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.isLoading = false
            $0.torrentList.torrents = []
        }

        #expect(invocationCount.value == 1)

        await store.send(.task)
        #expect(invocationCount.value == 1)

        await store.send(.editButtonTapped) {
            $0.editor = ServerEditorReducer.State(server: initialServer)
        }

        await store.send(.editor(.presented(.delegate(.didUpdate(updatedServer))))) {
            $0.server = updatedServer
            $0.editor = nil
            $0.connectionEnvironment = nil
            $0.connectionState.phase = .connecting
        }

        await store.receive(.delegate(.serverUpdated(updatedServer)))

        await store.receive(
            .connectionResponse(
                .success(
                    ServerDetailReducer.ConnectionResponse(
                        environment: secondEnvironment,
                        handshake: secondHandshake
                    )
                )
            )
        ) {
            $0.connectionEnvironment = secondEnvironment
            $0.connectionState.phase = .ready(
                .init(fingerprint: secondEnvironment.fingerprint, handshake: secondHandshake)
            )
        }
        await store.receive(.torrentList(.connectionAvailable(secondEnvironment))) {
            $0.torrentList.connectionEnvironment = secondEnvironment
            $0.torrentList.isLoading = true
            $0.torrentList.errorMessage = nil
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.isLoading = false
            $0.torrentList.torrents = []
        }

        #expect(invocationCount.value == 2)
    }

    @Test
    func resetTrustClearsTrustStoreOnly() async {
        let fingerprint = LockedValue<String?>(nil)
        let identityCapture = LockedValue<TransmissionServerTrustIdentity?>(nil)

        let server = ServerConfig.previewSecureSeedbox
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore(
                isSuppressed: { _ in false },
                setSuppressed: { _, _ in },
                reset: { value in fingerprint.set(value) }
            )
            dependencies.transmissionTrustStoreClient = TransmissionTrustStoreClient { identity in
                identityCapture.set(identity)
            }
        }

        await store.send(.resetTrustButtonTapped) {
            $0.alert = .resetTrustConfirmation
        }

        await store.send(.alert(.presented(.confirmReset))) {
            $0.alert = nil
        }

        await store.receive(.resetTrustSucceeded) {
            $0.alert = .resetTrustCompletion
        }

        #expect(fingerprint.value == nil)
        #expect(
            identityCapture.value
                == TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                ))
    }

    @Test
    func httpWarningResetClearsPreferences() async {
        let fingerprint = LockedValue<String?>(nil)
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore(
                isSuppressed: { _ in false },
                setSuppressed: { _, _ in },
                reset: { value in fingerprint.set(value) }
            )
        }

        await store.send(.httpWarningResetButtonTapped) {
            $0.alert = .httpWarningsReset
        }

        #expect(fingerprint.value == server.httpWarningFingerprint)
    }

    @Test
    func deleteFlowRequiresConfirmation() async {
        let deletedKeys = LockedValue<[TransmissionServerCredentialsKey]>([])
        let deletedFingerprints = LockedValue<[String]>([])
        let deletedIds = LockedValue<[UUID]>([])
        let deletedIdentity = LockedValue<TransmissionServerTrustIdentity?>(nil)

        let server = ServerConfig.previewSecureSeedbox
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.credentialsRepository = CredentialsRepository(
                save: { _ in },
                load: { _ in nil },
                delete: { key in deletedKeys.withValue { $0.append(key) } }
            )
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore(
                isSuppressed: { _ in false },
                setSuppressed: { _, _ in },
                reset: { value in deletedFingerprints.withValue { $0.append(value) } }
            )
            dependencies.transmissionTrustStoreClient = TransmissionTrustStoreClient { identity in
                deletedIdentity.set(identity)
            }
            dependencies.serverConfigRepository = ServerConfigRepository(
                load: { [] },
                upsert: { _ in [] },
                delete: { ids in
                    deletedIds.withValue { $0.append(contentsOf: ids) }
                    return []
                }
            )
        }

        await store.send(.deleteButtonTapped) {
            $0.alert = .deleteConfirmation
        }

        await store.send(.alert(.presented(.confirmDeletion))) {
            $0.alert = nil
            $0.isDeleting = true
        }

        await store.receive(.deleteCompleted(.success)) {
            $0.isDeleting = false
        }

        await store.receive(.delegate(.serverDeleted(server.id)))

        #expect(deletedIds.value == [server.id])
        #expect(deletedKeys.value == [server.credentialsKey!])
        #expect(deletedFingerprints.value == [server.httpWarningFingerprint])
        #expect(
            deletedIdentity.value
                == TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                ))
    }

    @Test
    func deleteFlowCancellationKeepsServer() async {
        let deleteCalled = LockedValue<Bool>(false)
        let server = ServerConfig.previewLocalHTTP

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConfigRepository = ServerConfigRepository(
                load: { [] },
                upsert: { _ in [] },
                delete: { _ in
                    deleteCalled.set(true)
                    return []
                }
            )
        }

        await store.send(.deleteButtonTapped) {
            $0.alert = .deleteConfirmation
        }

        await store.send(.alert(.presented(.cancelDeletion))) {
            $0.alert = nil
        }

        #expect(deleteCalled.value == false)
    }

    @Test
    func editFlowPropagatesUpdates() async {
        let server = ServerConfig.previewLocalHTTP
        var updated = server
        updated.name = "Updated"

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.editButtonTapped) {
            $0.editor = ServerEditorReducer.State(server: server)
        }

        await store.send(.editor(.presented(.delegate(.didUpdate(updated))))) {
            $0.server = updated
            $0.editor = nil
        }

        await store.receive(.delegate(.serverUpdated(updated)))
    }

    @Test
    func editFlowCancellationDismissesSheet() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.editButtonTapped) {
            $0.editor = ServerEditorReducer.State(server: server)
        }

        await store.send(.editor(.presented(.delegate(.cancelled)))) {
            $0.editor = nil
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&storage)
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

extension AlertState where Action == ServerDetailReducer.AlertAction {
    fileprivate static var resetTrustConfirmation: Self {
        AlertState {
            TextState("Сбросить доверие?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmReset) {
                TextState("Сбросить")
            }
            ButtonState(role: .cancel, action: .cancelReset) {
                TextState("Отмена")
            }
        } message: {
            TextState("Удалим сохранённые отпечатки сертификатов и решения \"Не предупреждать\".")
        }
    }

    fileprivate static var resetTrustCompletion: Self {
        AlertState {
            TextState("Доверие сброшено")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Готово")
            }
        } message: {
            TextState("При следующем подключении мы снова спросим подтверждение.")
        }
    }

    fileprivate static var httpWarningsReset: Self {
        AlertState {
            TextState("Предупреждения сброшены")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Готово")
            }
        } message: {
            TextState("Мы снова предупредим перед подключением по HTTP.")
        }
    }

    fileprivate static var deleteConfirmation: Self {
        AlertState {
            TextState("Удалить сервер?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeletion) {
                TextState("Удалить")
            }
            ButtonState(role: .cancel, action: .cancelDeletion) {
                TextState("Отмена")
            }
        } message: {
            TextState("Сервер и сохранённые креды будут удалены без возможности восстановления.")
        }
    }
}

// swiftlint:enable function_body_length type_body_length
