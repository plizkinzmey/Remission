import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Detail Connection & Management Tests")
@MainActor
struct ServerDetailFeatureConnectionTests {

    @Test("HTTP сервер требует подтверждения перед подключением")
    func testHTTPConnectionRequiresConfirmation() async {
        let server = ServerConfig.previewLocalHTTP
        let clock = TestClock()
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in false }
            $0.appClock = .test(clock: clock)
        }

        await store.send(.retryConnectionButtonTapped)

        await clock.advance(by: .seconds(1))

        await store.receive(.showHTTPWarning(server)) {
            $0.alert = AlertFactory.httpConnectionWarning(
                confirmAction: .confirmHTTPConnection,
                cancelAction: .cancelHTTPConnection
            )
        }
    }

    @Test("Успешное подключение обновляет состояние и окружение")
    func testConnectionResponseSuccess() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let handshake = TransmissionHandshakeResult(
            sessionID: "test-session",
            rpcVersion: 21,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.0",
            isCompatible: true
        )
        let response = ServerDetailReducer.ConnectionResponse(
            environment: environment,
            handshake: handshake
        )
        let updatedEnvironment = environment.updatingRPCVersion(handshake.rpcVersion)

        var state = ServerDetailReducer.State(server: server)
        state.connectionState.phase = .connecting
        state.torrentList.items = [
            TorrentListItem.State(torrent: .previewDownloading)
        ]

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        }
        store.exhaustivity = .off

        await store.send(.connectionResponse(.success(response))) {
            $0.connectionEnvironment = updatedEnvironment
            $0.connectionRetryAttempts = 0
            $0.connectionState.phase = .ready(
                .init(fingerprint: updatedEnvironment.fingerprint, handshake: handshake)
            )
            $0.torrentList.connectionEnvironment = updatedEnvironment
            $0.torrentList.cacheKey = updatedEnvironment.cacheKey
            $0.torrentList.handshake = handshake
            $0.torrentList.isAwaitingConnection = false
        }
    }

    @Test("Ошибка подключения переводит экран в offline и очищает список")
    func testConnectionResponseFailure() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let handshake = TransmissionHandshakeResult(
            sessionID: "test-session",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.0",
            isCompatible: true
        )
        let error = TestError(message: "Сбой соединения")

        var state = ServerDetailReducer.State(server: server)
        state.connectionEnvironment = environment
        state.connectionState.phase = .ready(
            .init(fingerprint: environment.fingerprint, handshake: handshake)
        )
        state.torrentList.connectionEnvironment = environment
        state.torrentList.handshake = handshake
        state.torrentList.items = [
            TorrentListItem.State(torrent: .previewDownloading)
        ]
        state.torrentList.storageSummary = StorageSummary(
            totalBytes: 1_000,
            freeBytes: 100,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        }
        store.exhaustivity = .off

        await store.send(.connectionResponse(.failure(error))) {
            $0.connectionEnvironment = nil
            $0.lastAppliedDefaultSpeedLimits = nil
            $0.torrentList.connectionEnvironment = nil
            $0.torrentList.handshake = nil
            $0.torrentList.items.removeAll()
            $0.torrentList.storageSummary = nil
            $0.connectionRetryAttempts = 1
            $0.connectionState.phase = .offline(
                .init(message: error.message, attempt: 1)
            )
            $0.errorPresenter.banner = .init(
                message: error.message,
                retry: .reconnect
            )
        }
    }

    @Test("Подтверждение удаления сервера запускает удаление и делегат")
    func testDeleteServerFlow() async {
        let server = ServerConfig.sample
        let clock = TestClock()

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0.credentialsRepository.delete = { @Sendable _ in }
            $0.offlineCacheRepository.clear = { @Sendable _ in }
            $0.httpWarningPreferencesStore.reset = { @Sendable _ in }
            $0.transmissionTrustStoreClient.deleteFingerprint = { @Sendable _ in }
            $0.serverConfigRepository.delete = { @Sendable _ in [] }
            $0.appClock = .test(clock: clock)
        }

        await store.send(.deleteButtonTapped) {
            $0.alert = AlertFactory.deleteConfirmation(
                title: L10n.tr("serverDetail.alert.delete.title"),
                message: L10n.tr("serverDetail.alert.delete.message"),
                confirmAction: .confirmDeletion,
                cancelAction: .cancelDeletion
            )
        }

        await store.send(.alert(.presented(.confirmDeletion))) {
            $0.alert = nil
            $0.isDeleting = true
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.deleteCompleted(.success)) {
            $0.isDeleting = false
        }

        await store.receive(.delegate(.serverDeleted(server.id)))
    }

    @Test("Изменение параметров сервера сбрасывает состояние и запускает переподключение")
    func testEditorUpdateTriggersReconnect() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let clock = TestClock()

        var updatedServer = server
        updatedServer.connection.host = "new-host.local"

        var state = ServerDetailReducer.State(server: server)
        state.connectionEnvironment = environment
        state.lastAppliedDefaultSpeedLimits = .init(
            downloadKilobytesPerSecond: 128,
            uploadKilobytesPerSecond: 64
        )
        state.connectionState.phase = .ready(
            .init(
                fingerprint: environment.fingerprint,
                handshake: TransmissionHandshakeResult(
                    sessionID: "test",
                    rpcVersion: 18,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission 4.0.0",
                    isCompatible: true
                )
            )
        )
        state.torrentList.items = [
            TorrentListItem.State(torrent: .previewDownloading)
        ]
        state.torrentList.phase = .loaded
        state.editor = ServerFormReducer.State(mode: .edit(server))

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionEnvironmentFactory = ServerConnectionEnvironmentFactory.unimplemented
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(
            .editor(.presented(.delegate(.didUpdate(updatedServer))))
        ) {
            $0.server = updatedServer
            $0.torrentList.serverID = updatedServer.id
            $0.torrentList = .init()
            $0.torrentList.serverID = updatedServer.id
            $0.connectionEnvironment = nil
            $0.lastAppliedDefaultSpeedLimits = nil
            $0.connectionState.phase = .connecting
            $0.connectionRetryAttempts = 0
            $0.torrentList.isAwaitingConnection = true
            $0.torrentList.phase = .idle
        }

        await store.receive(.torrentList(.teardown)) {
            $0.torrentList.isAwaitingConnection = false
        }

        await store.receive(.delegate(.serverUpdated(updatedServer)))

        // Advance clock to let startConnection run (it uses appClock for delays)
        await clock.advance(by: .seconds(5))

        // Factory is unimplemented, so connect throws and we get failure
        await store.receive(
            .connectionResponse(
                .failure(ServerConnectionEnvironmentFactoryError.notConfigured("unimplemented")))
        ) {
            $0.connectionState.phase = .offline(
                .init(
                    message: "ServerConnectionEnvironmentFactory (unimplemented) не настроена.",
                    attempt: 1))
            $0.torrentList.isAwaitingConnection = false
            $0.errorPresenter.banner = .init(
                message: "ServerConnectionEnvironmentFactory (unimplemented) не настроена.",
                retry: .reconnect)
        }

        await store.receive(.editor(.dismiss))
    }
}

private struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

private actor HandshakeGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        guard isOpen == false else { return }
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}