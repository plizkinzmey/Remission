import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Detail Add Torrent Logic")
@MainActor
struct ServerDetailAddTorrentTests {

    @Test("File import handles loader error")
    func testFileImportLoaderError() async {
        let server = ServerConfig.sample
        let url = URL(fileURLWithPath: "/tmp/broken.torrent")
        let errorMessage = "Loader failed"

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            // Loader throws an error. The reducer maps it to FileImportError.failed(error.localizedDescription)
            $0.torrentFileLoader.load = { @Sendable _ in throw TestError(message: errorMessage) }
        }

        await store.send(.fileImportResult(.success(url)))

        await store.receive { action in
            guard case .fileImportLoaded(.failure) = action else { return false }
            return true
        } assert: {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.readFileLoadedFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                // Reducer uses error.localizedDescription. For TestError, it's just the message.
                TextState(errorMessage)
            }
        }
    }

    @Test("File import failure action shows alert")
    func testFileImportFailureAction() async {
        let server = ServerConfig.sample
        let errorMessage = "Access denied"

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        }

        // FileImportResult.failure takes a String, not an Error object
        await store.send(.fileImportResult(.failure(errorMessage))) {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.readFileFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(errorMessage)
            }
        }
    }
}

private struct TestError: Error, LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
