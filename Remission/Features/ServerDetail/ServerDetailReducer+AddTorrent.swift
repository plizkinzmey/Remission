import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func handleFileImport(url: URL, state: inout State) -> Effect<Action> {
        guard url.pathExtension.lowercased() == "torrent" else {
            state.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.invalidFile.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("serverDetail.addTorrent.invalidFile.message"))
            }
            return .none
        }
        return .run { send in
            await send(
                .fileImportLoaded(
                    Result {
                        let data = try torrentFileLoader.load(url)
                        return PendingTorrentInput(
                            payload: .torrentFile(
                                data: data,
                                fileName: url.lastPathComponent
                            ),
                            sourceDescription: url.lastPathComponent
                        )
                    }.mapError { FileImportError.failed($0.localizedDescription) }
                )
            )
        }
    }

    func handleFileImportFailure(
        message: String,
        state: inout State
    ) -> Effect<Action> {
        state.alert = AlertState {
            TextState(L10n.tr("serverDetail.addTorrent.readFileFailed.title"))
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
        return .none
    }

    func handleFileImportLoaded(
        result: Result<PendingTorrentInput, FileImportError>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let input):
            guard let environment = state.connectionEnvironment else {
                state.pendingAddTorrentInput = input
                return .none
            }

            return .run { send in
                let session = try? await environment.withDependencies {
                    @Dependency(\.sessionRepository) var sessionRepo
                    return try await sessionRepo.fetchState()
                }

                await send(.addTorrentDataLoaded(input, session?.downloadDirectory))
            }

        case .failure(let error):
            state.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.readFileLoadedFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(error.message)
            }
            return .none
        }
    }

    func handleAddTorrentDataLoaded(
        input: PendingTorrentInput,
        downloadDir: String?,
        state: inout State
    ) -> Effect<Action> {
        var addState = AddTorrentReducer.State(
            pendingInput: input,
            connectionEnvironment: state.connectionEnvironment,
            serverID: state.server.id
        )
        if let downloadDir {
            addState.serverDownloadDirectory = downloadDir
            addState.destinationPath = downloadDir
        }
        state.addTorrent = addState
        return .none
    }
}
