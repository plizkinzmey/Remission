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
            state.pendingAddTorrentInput = input
            state.addTorrentSource?.selectedFileName = input.sourceDescription
            state.isFileImporterPresented = false
            return .none

        case .failure(let error):
            state.isFileImporterPresented = false
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

    func handleMagnetResponse(
        result: Result<String?, MagnetImportError>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let magnet):
            if let magnet {
                guard let url = URL(string: magnet),
                    url.scheme?.lowercased() == "magnet"
                else {
                    state.alert = AlertState {
                        TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.title"))
                    } actions: {
                        ButtonState(role: .cancel, action: .dismiss) {
                            TextState(L10n.tr("common.ok"))
                        }
                    } message: {
                        TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.message"))
                    }
                    return .none
                }
                state.addTorrent = AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(url: url, rawValue: magnet),
                        sourceDescription: "Magnet"
                    ),
                    connectionEnvironment: state.connectionEnvironment
                )
                return .none
            }
            state.isFileImporterPresented = true
            return .none

        case .failure(let error):
            state.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.processMagnetFailed.title"))
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
}
