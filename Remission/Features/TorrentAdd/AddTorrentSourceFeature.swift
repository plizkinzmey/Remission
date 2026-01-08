import ComposableArchitecture
import Foundation

@Reducer
struct AddTorrentSourceReducer {
    enum Source: String, CaseIterable, Equatable, Sendable {
        case torrentFile
        case magnetLink
    }

    @ObservableState
    struct State: Equatable {
        var source: Source = .magnetLink
        var magnetText: String = ""
        var selectedFileName: String? = nil
        @Presents var alert: AlertState<AlertAction>?

        init(source: Source = .torrentFile) {
            self.source = source
        }
    }

    enum Action: Equatable {
        case sourceChanged(Source)
        case magnetTextChanged(String)
        case chooseFileTapped
        case pasteFromClipboardTapped
        case pasteResponse(TaskResult<String?>)
        case continueTapped
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case closeRequested
        case fileRequested
        case fileSubmitted
        case magnetSubmitted(String)
    }

    @Dependency(\.magnetLinkClient) var magnetLinkClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .sourceChanged(let source):
                state.source = source
                if source == .magnetLink {
                    state.selectedFileName = nil
                }
                return .none

            case .magnetTextChanged(let value):
                state.magnetText = value
                return .none

            case .chooseFileTapped:
                return .send(.delegate(.fileRequested))

            case .pasteFromClipboardTapped:
                return .run { send in
                    await send(
                        .pasteResponse(
                            TaskResult {
                                try await magnetLinkClient.consumePendingMagnet()
                            }
                        )
                    )
                }

            case .pasteResponse(.success(let magnet)):
                guard let magnet else {
                    state.alert = AlertState {
                        TextState(L10n.tr("torrentAdd.source.noMagnet.title"))
                    } actions: {
                        ButtonState(role: .cancel, action: .dismiss) {
                            TextState(L10n.tr("common.ok"))
                        }
                    } message: {
                        TextState(L10n.tr("torrentAdd.source.noMagnet.message"))
                    }
                    return .none
                }
                state.magnetText = magnet
                state.source = .magnetLink
                return .none

            case .pasteResponse(.failure):
                state.alert = AlertState {
                    TextState(L10n.tr("torrentAdd.source.noMagnet.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(L10n.tr("torrentAdd.source.noMagnet.message"))
                }
                return .none

            case .continueTapped:
                switch state.source {
                case .torrentFile:
                    guard state.selectedFileName != nil else { return .none }
                    return .send(.delegate(.fileSubmitted))
                case .magnetLink:
                    let trimmed = state.magnetText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.isEmpty == false else { return .none }
                    guard let url = URL(string: trimmed),
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
                    return .send(.delegate(.magnetSubmitted(url.absoluteString)))
                }

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
