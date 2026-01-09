import ComposableArchitecture
import Foundation

extension AddTorrentReducer {
    func pendingInput(fromMagnet rawValue: String) -> PendingTorrentInput? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard let url = URL(string: trimmed),
            url.scheme?.lowercased() == "magnet"
        else {
            return nil
        }
        return PendingTorrentInput(
            payload: .magnetLink(url: url, rawValue: trimmed),
            sourceDescription: "Magnet"
        )
    }

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
        state.isFileImporterPresented = false
        switch result {
        case .success(let input):
            state.source = .torrentFile
            state.pendingInput = input
            state.selectedFileName = input.sourceDescription
            return .none
        case .failure(let error):
            state.pendingInput = nil
            state.selectedFileName = nil
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
}
