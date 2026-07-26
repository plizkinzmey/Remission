import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class AppFeatureTests: XCTestCase {
    func testTrustPromptReceivedPresentsSheet() async {
        let challenge = TransmissionTrustChallenge(
            identity: .init(host: "example.com", port: 443, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "example.com",
                organization: "Test Org",
                validFrom: nil,
                validUntil: nil,
                sha256Fingerprint: Data([0x01, 0x02, 0x03])
            )
        )
        let prompt = TransmissionTrustPrompt(challenge: challenge, resolver: { _ in })

        let store = TestStoreFactory.makeTestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer()
        )

        await store.send(.trustPromptReceived(prompt)) {
            $0.trustPrompt = .init(prompt: prompt)
            $0.trustPromptQueue = []
        }
    }
    func testTrustPromptReceivedQueuesAdditionalPrompts() async {
        let c1 = TransmissionTrustChallenge(
            identity: .init(host: "one.example.com", port: 443, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "one.example.com",
                organization: "Test Org",
                validFrom: nil,
                validUntil: nil,
                sha256Fingerprint: Data([0x0a])
            )
        )
        let c2 = TransmissionTrustChallenge(
            identity: .init(host: "two.example.com", port: 443, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "two.example.com",
                organization: "Test Org",
                validFrom: nil,
                validUntil: nil,
                sha256Fingerprint: Data([0x0b])
            )
        )
        let p1 = TransmissionTrustPrompt(challenge: c1, resolver: { _ in })
        let p2 = TransmissionTrustPrompt(challenge: c2, resolver: { _ in })

        var state = AppReducer.State()
        state.trustPrompt = .init(prompt: p1)

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        await store.send(.trustPromptReceived(p2)) {
            $0.trustPromptQueue = [p2]
        }
    }
    func testOpenTorrentFileIgnoresNonFileURL() async {
        // Этот тест защищает от обработки внешних URL как локальных .torrent.
        let store = TestStoreFactory.makeTestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer()
        )

        let url = URL(string: "https://example.com/file.torrent")!

        await store.send(.openTorrentFile(url))
    }
    func testOpenTorrentFileIgnoresNonTorrentExtension() async {
        // Мы должны принимать только .torrent файлы.
        let store = TestStoreFactory.makeTestStore(
            initialState: AppReducer.State(),
            reducer: AppReducer()
        )

        let url = URL(fileURLWithPath: "/tmp/file.txt")

        await store.send(.openTorrentFile(url))
    }
    func testOpenTorrentFileUsesNewestServer() async {
        // При отсутствии активного сервера выбираем самый новый по createdAt.
        let older = makeServer(name: "Old", createdAt: 1)
        let newer = makeServer(name: "New", createdAt: 2)
        var state = AppReducer.State()
        state.serverList.servers = [older, newer]

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        let url = URL(fileURLWithPath: "/tmp/sample.torrent")
        await store.send(.openTorrentFile(url))

        XCTAssertTrue(store.state.path.count == 1)
        if case .serverDetail(let detail) = store.state.path.last {
            XCTAssertTrue(detail.server.id == newer.id)
        } else {
            XCTFail("Ожидали serverDetail в path")
        }
        guard let openedID = store.state.path.ids.last else {
            XCTFail("Не смогли получить ID открытого сервера")
            return
        }

        await store.receive(
            .path(.element(id: openedID, action: .serverDetail(.fileImportResult(.success(url)))))
        )
    }
    func testOpenTorrentFileUsesActiveServer() async {
        // Если сервер уже открыт, отправляем файл прямо в него.
        let server = makeServer(name: "Active", createdAt: 1)
        var state = AppReducer.State()
        state.path.append(.serverDetail(ServerDetailReducer.State(server: server)))

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        let url = URL(fileURLWithPath: "/tmp/active.torrent")
        let activeID: StackElementID? = state.path.ids.last

        await store.send(.openTorrentFile(url))

        if let activeID {
            await store.receive(
                .path(
                    .element(id: activeID, action: .serverDetail(.fileImportResult(.success(url)))))
            )
        } else {
            XCTFail("Ожидали активный сервер в path")
        }
    }
    func testServerListTaskAutoOpensSingleServer() async {
        // При единственном сервере и пустом path сразу открываем детали.
        let server = makeServer(name: "Single", createdAt: 1)
        var state = AppReducer.State()
        state.serverList.servers = [server]

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        await store.send(.serverList(.task))
        XCTAssertTrue(store.state.path.count == 1)
        if case .serverDetail(let detail) = store.state.path.last {
            XCTAssertTrue(detail.server.id == server.id)
        } else {
            XCTFail("Ожидали serverDetail в path")
        }
    }
    func testServerSelectedOpensPendingTorrent() async {
        // Pending файл должен открываться сразу после выбора сервера.
        let server = makeServer(name: "Selected", createdAt: 1)
        var state = AppReducer.State()
        let url = URL(fileURLWithPath: "/tmp/pending.torrent")
        state.pendingTorrentFileURL = url

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        await store.send(.serverList(.delegate(.serverSelected(server))))
        XCTAssertTrue(store.state.pendingTorrentFileURL == nil)
        XCTAssertTrue(store.state.path.count == 1)
        if case .serverDetail(let detail) = store.state.path.last {
            XCTAssertTrue(detail.server.id == server.id)
        } else {
            XCTFail("Ожидали serverDetail в path")
        }
        guard let openedID = store.state.path.ids.last else {
            XCTFail("Не смогли получить ID открытого сервера")
            return
        }

        await store.receive(
            .path(.element(id: openedID, action: .serverDetail(.fileImportResult(.success(url)))))
        )
    }
    func testServerRepositoryResponseOpensPendingFile() async {
        // После загрузки серверов pending файл должен открыться в выбранном сервере.
        let older = makeServer(name: "Old", createdAt: 1)
        let newer = makeServer(name: "New", createdAt: 2)
        let url = URL(fileURLWithPath: "/tmp/queued.torrent")

        var state = AppReducer.State()
        state.pendingTorrentFileURL = url

        let store = TestStoreFactory.makeTestStore(
            initialState: state,
            reducer: AppReducer()
        )

        await store.send(
            .serverList(.serverRepositoryResponse(.success([older, newer])))
        )
        XCTAssertTrue(store.state.pendingTorrentFileURL == nil)
        XCTAssertTrue(store.state.path.count == 1)
        if case .serverDetail(let detail) = store.state.path.last {
            XCTAssertTrue(detail.server.id == newer.id)
        } else {
            XCTFail("Ожидали serverDetail в path")
        }
        guard let openedID = store.state.path.ids.last else {
            XCTFail("Не смогли получить ID открытого сервера")
            return
        }

        await store.receive(
            .path(.element(id: openedID, action: .serverDetail(.fileImportResult(.success(url)))))
        )
    }
}

private func makeServer(name: String, createdAt: TimeInterval) -> ServerConfig {
    var server = ServerConfig(
        name: name,
        connection: .init(host: "example.com", port: 9091),
        security: .http,
        authentication: .init(username: "user")
    )
    server.createdAt = Date(timeIntervalSince1970: createdAt)
    return server
}
