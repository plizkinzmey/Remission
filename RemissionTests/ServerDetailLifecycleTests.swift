import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerDetailLifecycleTests {
    @Test
    func resetTrustClearsTrustStoreOnly() async {
        let fingerprint = ServerDetailLockedValue<String?>(nil)
        let identityCapture = ServerDetailLockedValue<TransmissionServerTrustIdentity?>(nil)

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
    func connectionFailureTriggersTorrentListTeardown() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failure
            var errorDescription: String? { "failure" }
        }

        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(server: server)

        var initialState = ServerDetailReducer.State(server: server)
        initialState.connectionEnvironment = environment
        initialState.connectionState.phase = .ready(
            .init(fingerprint: environment.fingerprint, handshake: handshake)
        )
        initialState.torrentList.connectionEnvironment = environment

        let store = TestStore(
            initialState: initialState
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.connectionResponse(.failure(DummyError.failure))) {
            $0.connectionEnvironment = nil
            $0.connectionState.phase = .failed(.init(message: "failure"))
            $0.torrentList = TorrentListReducer.State()
            $0.alert = .connectionFailure(message: "failure")
        }

        await store.receive(.torrentList(.teardown))
    }

    @Test
    func httpWarningResetClearsPreferences() async {
        let fingerprint = ServerDetailLockedValue<String?>(nil)
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
        let deletedKeys = ServerDetailLockedValue<[TransmissionServerCredentialsKey]>([])
        let deletedFingerprints = ServerDetailLockedValue<[String]>([])
        let deletedIds = ServerDetailLockedValue<[UUID]>([])
        let deletedIdentity = ServerDetailLockedValue<TransmissionServerTrustIdentity?>(nil)

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
        let deleteCalled = ServerDetailLockedValue<Bool>(false)
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
