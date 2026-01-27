import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server List Storage Tests")
@MainActor
struct ServerListStorageTests {

    @Test("StorageRequested загружает summary")
    func testStorageRequestedSuccess() async {
        // Проверяем, что storageRequested вызывает расчёт StorageSummary и снимает флаг загрузки.
        let server = ServerConfig.previewLocalHTTP
        let torrents = [Torrent.previewDownloading, Torrent.previewCompleted]
        let session = SessionState.previewActive

        let torrentRepository = makeTorrentRepository(list: torrents)
        let sessionRepository = makeSessionRepository(state: session)
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            torrentRepository: torrentRepository,
            sessionRepository: sessionRepository
        )

        var state = ServerListReducer.State()
        state.servers = [server]
        state.connectionStatuses[server.id] = .init(phase: .connected(.uiTestPlaceholder))

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in environment }
        }
        store.exhaustivity = .off

        await store.send(.storageRequested(server.id)) {
            $0.connectionStatuses[server.id]?.isLoadingStorage = true
        }

        let expectedSummary = StorageSummary.calculate(
            torrents: torrents,
            session: session,
            updatedAt: nil
        )

        await store.receive(.storageResponse(server.id, .success(expectedSummary!))) {
            $0.connectionStatuses[server.id]?.storageSummary = expectedSummary
            $0.connectionStatuses[server.id]?.isLoadingStorage = false
        }
    }

    @Test("StorageRequested обрабатывает ошибку")
    func testStorageRequestedFailure() async {
        // Проверяем, что ошибка при загрузке storage сбрасывает флаг загрузки.
        let server = ServerConfig.previewLocalHTTP
        let error = TestError(message: "storage-failed")

        var state = ServerListReducer.State()
        state.servers = [server]
        state.connectionStatuses[server.id] = .init(phase: .connected(.uiTestPlaceholder))

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in
                throw error
            }
        }
        store.exhaustivity = .off

        await store.send(.storageRequested(server.id)) {
            $0.connectionStatuses[server.id]?.isLoadingStorage = true
        }

        await store.receive(.storageResponse(server.id, .failure(error))) {
            $0.connectionStatuses[server.id]?.isLoadingStorage = false
        }
    }
}

private func makeSessionRepository(state: SessionState) -> SessionRepository {
    SessionRepository(
        performHandshake: {
            .init(
                sessionID: "session",
                rpcVersion: state.rpc.rpcVersion,
                minimumSupportedRpcVersion: state.rpc.rpcVersionMinimum,
                serverVersionDescription: state.rpc.serverVersion,
                isCompatible: true
            )
        },
        fetchState: { state },
        updateState: { _ in state },
        checkCompatibility: { .init(isCompatible: true, rpcVersion: state.rpc.rpcVersion) }
    )
}

private func makeTorrentRepository(list: [Torrent]) -> TorrentRepository {
    TorrentRepository(
        fetchList: { list },
        fetchDetails: { _ in list[0] },
        add: { _, _, _, _ in
            TorrentRepository.AddResult(
                status: .added,
                id: list[0].id,
                name: list[0].name,
                hashString: "hash"
            )
        },
        start: { _ in },
        stop: { _ in },
        remove: { _, _ in },
        verify: { _ in },
        updateTransferSettings: { _, _ in },
        updateLabels: { _, _ in },
        updateFileSelection: { _, _ in }
    )
}

private struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
