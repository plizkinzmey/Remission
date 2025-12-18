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
        store.exhaustivity = .off

        await store.send(.connectionResponse(.failure(DummyError.failure))) {
            $0.connectionEnvironment = nil
            $0.connectionRetryAttempts = 1
            $0.connectionState.phase = .offline(.init(message: "failure", attempt: 1))
            $0.torrentList.connectionEnvironment = nil
            $0.errorPresenter.banner = .init(
                message: "failure",
                retry: .reconnect
            )
        }

        await store.receive(.torrentList(.teardown))
        await store.receive(.torrentList(.goOffline(message: "failure"))) {
            $0.torrentList.offlineState = .init(message: "failure", lastUpdatedAt: nil)
            $0.torrentList.phase = .offline(
                .init(message: "failure", lastUpdatedAt: nil)
            )
        }
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
        let capture = DeleteFlowCapture()

        let server = ServerConfig.previewSecureSeedbox
        let cacheKey = OfflineCacheKey(
            serverID: server.id,
            cacheFingerprint: "fixture-cache",
            rpcVersion: nil
        )
        let snapshotClient = capture.offlineCache.client(cacheKey)
        await seedOfflineSnapshot(client: snapshotClient)

        let store = makeDeleteFlowStore(
            server: server,
            capture: capture
        )

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
        let snapshot = try? await snapshotClient.load()
        #expect(snapshot == nil)

        #expect(capture.deletedIds.value == [server.id])
        #expect(capture.deletedKeys.value == [server.credentialsKey!])
        #expect(capture.deletedFingerprints.value == [server.httpWarningFingerprint])
        #expect(
            capture.deletedIdentity.value
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
        }

        await store.receive(.delegate(.serverUpdated(updated)))
        await store.receive(.editor(.dismiss)) {
            $0.editor = nil
        }
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

        await store.send(.editor(.presented(.delegate(.cancelled))))

        await store.receive(.editor(.dismiss)) {
            $0.editor = nil
        }
    }
}

@MainActor
private func seedOfflineSnapshot(client: OfflineCacheClient) async {
    _ = try? await client.updateTorrents([Torrent.previewDownloading])
}

private struct DeleteFlowCapture: Sendable {
    var offlineCache: OfflineCacheRepository = .inMemory()
    var deletedKeys: ServerDetailLockedValue<[TransmissionServerCredentialsKey]> = .init([])
    var deletedFingerprints: ServerDetailLockedValue<[String]> = .init([])
    var deletedIds: ServerDetailLockedValue<[UUID]> = .init([])
    var deletedIdentity: ServerDetailLockedValue<TransmissionServerTrustIdentity?> = .init(nil)
}

@MainActor
private func makeDeleteFlowStore(
    server: ServerConfig,
    capture: DeleteFlowCapture
) -> TestStore<ServerDetailReducer.State, ServerDetailReducer.Action> {
    TestStore(
        initialState: ServerDetailReducer.State(server: server)
    ) {
        ServerDetailReducer()
    } withDependencies: { dependencies in
        dependencies = AppDependencies.makeTestDefaults()
        dependencies.offlineCacheRepository = capture.offlineCache
        dependencies.credentialsRepository = CredentialsRepository(
            save: { _ in },
            load: { _ in nil },
            delete: { key in capture.deletedKeys.withValue { $0.append(key) } }
        )
        dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore(
            isSuppressed: { _ in false },
            setSuppressed: { _, _ in },
            reset: { value in capture.deletedFingerprints.withValue { $0.append(value) } }
        )
        dependencies.transmissionTrustStoreClient = TransmissionTrustStoreClient { identity in
            capture.deletedIdentity.set(identity)
        }
        dependencies.serverConfigRepository = ServerConfigRepository(
            load: { [] },
            upsert: { _ in [] },
            delete: { ids in
                capture.deletedIds.withValue { $0.append(contentsOf: ids) }
                return []
            }
        )
    }
}

extension AlertState where Action == ServerDetailReducer.AlertAction {
    fileprivate static var resetTrustConfirmation: Self {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.trustReset.title"))
        } actions: {
            ButtonState(role: .destructive, action: .confirmReset) {
                TextState(L10n.tr("serverDetail.alert.trustReset.confirm"))
            }
            ButtonState(role: .cancel, action: .cancelReset) {
                TextState(L10n.tr("serverDetail.alert.trustReset.cancel"))
            }
        } message: {
            TextState(L10n.tr("serverDetail.alert.trustReset.message"))
        }
    }

    fileprivate static var resetTrustCompletion: Self {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.trustResetDone.title"))
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("serverDetail.alert.trustResetDone.button"))
            }
        } message: {
            TextState(L10n.tr("serverDetail.alert.trustResetDone.message"))
        }
    }

    fileprivate static var httpWarningsReset: Self {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.httpWarningsReset.title"))
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("serverDetail.alert.httpWarningsReset.button"))
            }
        } message: {
            TextState(L10n.tr("serverDetail.alert.httpWarningsReset.message"))
        }
    }

    fileprivate static var deleteConfirmation: Self {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.delete.title"))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeletion) {
                TextState(L10n.tr("serverDetail.alert.delete.confirm"))
            }
            ButtonState(role: .cancel, action: .cancelDeletion) {
                TextState(L10n.tr("serverDetail.alert.delete.cancel"))
            }
        } message: {
            TextState(L10n.tr("serverDetail.alert.delete.message"))
        }
    }
}
