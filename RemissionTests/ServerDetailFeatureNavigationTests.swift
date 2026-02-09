import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Detail Navigation & Import Tests")
@MainActor
struct ServerDetailFeatureNavigationTests {

    @Test("Тап по торренту открывает детальный экран")
    func testRowTappedOpensTorrentDetail() async {
        // Проверяем, что выбор торрента создаёт состояние TorrentDetail с нужным ID.
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let torrent = Torrent.previewDownloading
        let item = TorrentListItem.State(torrent: torrent)

        var state = ServerDetailReducer.State(server: server)
        state.connectionEnvironment = environment
        state.torrentList.items = [item]

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        }

        await store.send(.torrentList(.rowTapped(torrent.id))) {
            $0.torrentDetail = TorrentDetailReducer.State(
                torrentID: torrent.id,
                torrent: torrent,
                connectionEnvironment: environment
            )
        }

        await store.receive(.torrentList(.delegate(.openTorrent(torrent.id))))
    }

    @Test("Кнопка добавления торрента открывает AddTorrent")
    func testAddTorrentButtonTappedOpensAddTorrent() async {
        // Проверяем, что кнопка добавления создаёт состояние AddTorrent с serverID.
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)

        var state = ServerDetailReducer.State(server: server)
        state.connectionEnvironment = environment

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        }

        await store.send(.torrentList(.addTorrentButtonTapped)) {
            $0.addTorrent = AddTorrentReducer.State(
                connectionEnvironment: environment,
                serverID: server.id
            )
        }

        await store.receive(.torrentList(.delegate(.addTorrentRequested)))
    }

    @Test("Импорт файла создаёт AddTorrent и пробрасывает событие")
    func testFileImportResultSuccess() async {
        // Проверяем, что успешный выбор файла создаёт PendingTorrentInput.
        // Если connectionEnvironment ещё нет, ввод сохраняется в pendingAddTorrentInput
        // и будет обработан позже при успешном подключении.
        let server = ServerConfig.sample
        let url = URL(fileURLWithPath: "/tmp/test.torrent")
        let fileData = Data([0x01, 0x02])

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            $0.torrentFileLoader.load = { @Sendable _ in fileData }
        }
        store.exhaustivity = .off

        await store.send(.fileImportResult(.success(url)))

        await store.receive {
            guard case .fileImportLoaded(.success) = $0 else { return false }
            return true
        } assert: {
            $0.pendingAddTorrentInput = PendingTorrentInput(
                payload: .torrentFile(data: fileData, fileName: url.lastPathComponent),
                sourceDescription: url.lastPathComponent
            )
        }
    }

    @Test("Обработка загруженного файла создаёт PendingTorrentInput")
    func testHandleFileImportLoadedSuccess() async {
        // Проверяем, что готовые данные торрента сохраняются в pending,
        // если connectionEnvironment ещё нет.
        let server = ServerConfig.sample
        let input = PendingTorrentInput(
            payload: .torrentFile(data: Data([0x01, 0x02]), fileName: "file.torrent"),
            sourceDescription: "file.torrent"
        )
        var state = ServerDetailReducer.State(server: server)

        _ = ServerDetailReducer().handleFileImportLoaded(
            result: .success(input),
            state: &state
        )

        #expect(state.pendingAddTorrentInput == input)
        #expect(state.addTorrent == nil)
    }

    @Test("Неверное расширение файла показывает alert")
    func testHandleFileImportInvalidExtension() async {
        // Проверяем, что файл с неверным расширением создаёт alert и не запускает импорт.
        let server = ServerConfig.sample
        let url = URL(fileURLWithPath: "/tmp/readme.txt")
        var state = ServerDetailReducer.State(server: server)

        _ = ServerDetailReducer().handleFileImport(url: url, state: &state)

        #expect(state.alert != nil)
    }
}
