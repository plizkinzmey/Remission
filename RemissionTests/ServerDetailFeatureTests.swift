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

        let preferences = UserPreferences(
            pollingInterval: 5,
            isAutoRefreshEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: nil,
                uploadKilobytesPerSecond: nil
            )
        )

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
        }
        store.exhaustivity = .off

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
            $0.torrentList.connectionEnvironment = environment
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
        await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
            $0.torrentList.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.phase = .loaded
            $0.torrentList.items = []
            $0.torrentList.failedAttempts = 0
        }
    }

    @Test
    func torrentDetailReusesExistingConnectionEnvironment() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session-42",
            rpcVersion: 21,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.1",
            isCompatible: true
        )
        let torrent = DomainFixtures.torrentDownloading
        let repository = TorrentRepository.test(fetchList: { [torrent] })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake,
            torrentRepository: repository
        )
        let invocationCount = LockedValue(0)
        let preferences = DomainFixtures.userPreferences

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .init { _ in
                invocationCount.withValue { $0 += 1 }
                return environment
            }
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
            dependencies.torrentRepository = repository
        }
        store.exhaustivity = .off

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
            $0.torrentList.connectionEnvironment = environment
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
        await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
            $0.torrentList.pollingInterval = .milliseconds(
                Int(preferences.pollingInterval * 1_000)
            )
            $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
            $0.torrentList.hasLoadedPreferences = true
        }
        await store.receive(.torrentList(.torrentsResponse(.success([torrent])))) {
            $0.torrentList.phase = .loaded
            $0.torrentList.items = [
                TorrentListItem.State(torrent: torrent)
            ]
            $0.torrentList.failedAttempts = 0
            $0.torrentList.isRefreshing = false
        }

        await store.send(.torrentList(.delegate(.openTorrent(torrent.id)))) {
            #expect($0.torrentDetail?.connectionEnvironment == environment)
            #expect($0.torrentDetail?.torrentID == torrent.id)
        }

        #expect(invocationCount.value == 1)
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
    func addTorrentRequestShowsPlaceholderAlert() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.torrentList(.delegate(.addTorrentRequested))) {
            $0.alert = AlertState {
                TextState("Добавление торрента")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Готово")
                }
            } message: {
                TextState("Экран добавления пока не реализован. Сообщим, как только появится.")
            }
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

        let preferences = UserPreferences(
            pollingInterval: 5,
            isAutoRefreshEnabled: false,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: nil,
                uploadKilobytesPerSecond: nil
            )
        )

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
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
        }
        store.exhaustivity = .off

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
            $0.torrentList.connectionEnvironment = firstEnvironment
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
        await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
            $0.torrentList.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.phase = .loaded
            $0.torrentList.items = []
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
            $0.torrentList = TorrentListReducer.State()
        }

        await store.receive(.torrentList(.teardown))

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
            $0.torrentList.connectionEnvironment = secondEnvironment
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
        await store.receive(.torrentList(.userPreferencesResponse(.success(preferences)))) {
            $0.torrentList.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.torrentList.isPollingEnabled = preferences.isAutoRefreshEnabled
        }
        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.phase = .loaded
            $0.torrentList.items = []
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

    @Test
    func preferencesUpdatePropagatesToTorrentList() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "observer",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake
        )

        let preferencesBox = LockedValue(DomainFixtures.userPreferences)
        let continuationBox = PreferencesContinuationBox()

        let repository = UserPreferencesRepository(
            load: { preferencesBox.value },
            updatePollingInterval: { interval in
                var updated = preferencesBox.value
                updated.pollingInterval = interval
                preferencesBox.set(updated)
                return updated
            },
            setAutoRefreshEnabled: { isEnabled in
                var updated = preferencesBox.value
                updated.isAutoRefreshEnabled = isEnabled
                preferencesBox.set(updated)
                return updated
            },
            updateDefaultSpeedLimits: { limits in
                var updated = preferencesBox.value
                updated.defaultSpeedLimits = limits
                preferencesBox.set(updated)
                return updated
            },
            observe: {
                AsyncStream { cont in
                    Task {
                        await continuationBox.set(cont)
                    }
                }
            }
        )

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
            dependencies.userPreferencesRepository = repository
        }
        store.exhaustivity = .off

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
            $0.torrentList.connectionEnvironment = environment
        }

        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }

        let initialPreferences = preferencesBox.value
        await store.receive(.torrentList(.userPreferencesResponse(.success(initialPreferences)))) {
            $0.torrentList.pollingInterval = .milliseconds(
                Int(initialPreferences.pollingInterval * 1_000)
            )
            $0.torrentList.isPollingEnabled = initialPreferences.isAutoRefreshEnabled
        }

        await store.receive(.torrentList(.torrentsResponse(.success([])))) {
            $0.torrentList.phase = .loaded
        }

        var updated = preferencesBox.value
        updated.pollingInterval = 30
        updated.isAutoRefreshEnabled = false
        preferencesBox.set(updated)
        await continuationBox.yield(updated)

        await store.receive(.torrentList(.userPreferencesResponse(.success(updated)))) {
            $0.torrentList.pollingInterval = .seconds(30)
            $0.torrentList.isPollingEnabled = false
        }

        await continuationBox.finish()
    }
}

extension UserPreferencesRepository {
    fileprivate static func testValue(preferences: UserPreferences) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
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

private actor PreferencesContinuationBox {
    private var continuation: AsyncStream<UserPreferences>.Continuation?

    func set(_ continuation: AsyncStream<UserPreferences>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ preferences: UserPreferences) {
        continuation?.yield(preferences)
    }

    func finish() {
        continuation?.finish()
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
