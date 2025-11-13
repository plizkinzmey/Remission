import ComposableArchitecture
import Testing

@testable import Remission

@Suite("TorrentListReducer")
struct TorrentListReducerTests {
    @MainActor
    @Test("connectionAvailable запускает загрузку списка")
    func connectionFetchSuccess() async {
        let torrents: [Torrent] = [.previewDownloading]
        let repository = TorrentRepository.test(
            fetchList: {
                torrents
            }
        )
        let server = ServerConfig.previewLocalHTTP
        let environment = ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: .placeholder,
                torrentRepository: repository,
                sessionRepository: .placeholder
            )
        )

        let store = TestStoreFactory.make(
            initialState: TorrentListReducer.State()
        ) {
            TorrentListReducer()
        } configure: { dependencies in
            dependencies.torrentListPollingInterval = nil
        }

        await store.send(.connectionAvailable(environment)) {
            $0.connectionEnvironment = environment
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.torrentsResponse(.success(torrents))) {
            $0.isLoading = false
            $0.torrents = IdentifiedArrayOf(uniqueElements: torrents)
        }
    }

    @MainActor
    @Test("ошибка загрузки переводит редьюсер в failed-состояние")
    func fetchFailureShowsError() async {
        enum DummyError: Error { case failed }

        let repository = TorrentRepository.test(
            fetchList: {
                throw DummyError.failed
            }
        )
        let server = ServerConfig.previewLocalHTTP
        let environment = ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: .placeholder,
                torrentRepository: repository,
                sessionRepository: .placeholder
            )
        )

        let store = TestStoreFactory.make(
            initialState: TorrentListReducer.State()
        ) {
            TorrentListReducer()
        } configure: { dependencies in
            dependencies.torrentListPollingInterval = nil
        }

        await store.send(.connectionAvailable(environment)) {
            $0.connectionEnvironment = environment
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            $0.isLoading = false
            $0.errorMessage = "failed"
        }
    }
}
