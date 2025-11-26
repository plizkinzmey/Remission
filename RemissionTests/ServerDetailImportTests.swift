import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length

@MainActor
struct ServerDetailImportTests {
    @Test
    func addTorrentRequestFromListShowsImporterWhenNoMagnet() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.magnetLinkClient = MagnetLinkClient(
                consumePendingMagnet: { nil }
            )
        }

        await store.send(.torrentList(.delegate(.addTorrentRequested)))
        await store.receive(.magnetLinkResponse(.success(nil))) {
            $0.isFileImporterPresented = true
        }
    }

    @Test
    func magnetImportOpensAddTorrentSheet() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.magnetLinkClient = MagnetLinkClient(
                consumePendingMagnet: { "magnet:?xt=urn:btih:demo" }
            )
        }

        await store.send(.torrentList(.delegate(.addTorrentRequested)))
        await store.receive(.magnetLinkResponse(.success("magnet:?xt=urn:btih:demo"))) {
            $0.addTorrent = AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: $0.connectionEnvironment
            )
        }
    }

    @Test
    func invalidMagnetShowsAlert() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.magnetLinkClient = MagnetLinkClient(
                consumePendingMagnet: { "http://example.com" }
            )
        }

        await store.send(.torrentList(.delegate(.addTorrentRequested)))
        await store.receive(.magnetLinkResponse(.success("http://example.com"))) {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.message"))
            }
        }
    }

    @Test
    func fileImportProducesPendingInput() async {
        let server = ServerConfig.previewLocalHTTP
        let dummyURL = URL(fileURLWithPath: "/tmp/sample.torrent")
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.torrentFileLoader = TorrentFileLoaderDependency(
                load: { _ in Data([0x01, 0x02]) }
            )
        }

        await store.send(.fileImportResult(.success(dummyURL)))
        await store.receive(
            .fileImportLoaded(
                .success(
                    .init(
                        payload: .torrentFile(
                            data: Data([0x01, 0x02]),
                            fileName: "sample.torrent"
                        ),
                        sourceDescription: "sample.torrent"
                    )
                )
            )
        ) {
            $0.addTorrent = AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .torrentFile(
                        data: Data([0x01, 0x02]),
                        fileName: "sample.torrent"
                    ),
                    sourceDescription: "sample.torrent"
                ),
                connectionEnvironment: $0.connectionEnvironment
            )
            $0.isFileImporterPresented = false
        }
    }

    @Test
    func magnetImportFailureShowsAlert() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.magnetLinkClient = MagnetLinkClient(
                consumePendingMagnet: {
                    struct DummyError: LocalizedError {
                        var errorDescription: String? { "Magnet access failed" }
                    }
                    throw DummyError()
                }
            )
        }

        await store.send(.torrentList(.delegate(.addTorrentRequested)))
        await store.receive(.magnetLinkResponse(.failure(.failed("Magnet access failed")))) {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.processMagnetFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState("Magnet access failed")
            }
        }
    }

    @Test
    func fileImportFailureShowsAlert() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                state.isFileImporterPresented = true
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.fileImportResult(.failure("Permission denied"))) {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.readFileFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState("Permission denied")
            }
        }
    }

    @Test
    func fileImportLoadedFailureShowsAlert() async {
        let server = ServerConfig.previewLocalHTTP
        let store = TestStore(
            initialState: {
                var state = ServerDetailReducer.State(server: server)
                state.torrentList.connectionEnvironment = .preview(server: server)
                return state
            }()
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.fileImportLoaded(.failure(.failed("Corrupted file")))) {
            $0.isFileImporterPresented = false
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.readFileLoadedFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState("Corrupted file")
            }
        }
    }
}

// swiftlint:enable function_body_length
