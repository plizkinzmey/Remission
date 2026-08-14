import ComposableArchitecture
import Foundation

@Reducer
struct TorrentTransferLimitsReducer {
    @ObservableState
    struct State: Equatable {
        var downloadLimit: Int = 0
        var downloadLimited: Bool = false
        var uploadLimit: Int = 0
        var uploadLimited: Bool = false
    }

    enum Action: Equatable {
        case toggleDownloadLimit(Bool)
        case toggleUploadLimit(Bool)
        case downloadLimitChanged(Int)
        case uploadLimitChanged(Int)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                return .send(
                    .delegate(
                        .updateTransferLimit(
                            .download(
                                .init(isEnabled: isEnabled, kilobytesPerSecond: state.downloadLimit)
                            )
                        )))

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                return .send(
                    .delegate(
                        .updateTransferLimit(
                            .upload(
                                .init(isEnabled: isEnabled, kilobytesPerSecond: state.uploadLimit))
                        )))

            case .downloadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.downloadLimit = bounded
                guard state.downloadLimited else { return .none }
                return .send(
                    .delegate(
                        .updateTransferLimit(
                            .download(.init(isEnabled: true, kilobytesPerSecond: bounded))
                        )))

            case .uploadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.uploadLimit = bounded
                guard state.uploadLimited else { return .none }
                return .send(
                    .delegate(
                        .updateTransferLimit(
                            .upload(.init(isEnabled: true, kilobytesPerSecond: bounded))
                        )))

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentTransferLimitsReducer.Action {
    enum Delegate: Equatable {
        case updateTransferLimit(TransferLimitUpdate)
    }
}
