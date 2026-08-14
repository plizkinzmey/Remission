import ComposableArchitecture
import Foundation

@Reducer
struct TorrentStatsReducer {
    @ObservableState
    struct State: Equatable {
        var speedHistory: TorrentDetailSpeedHistory = .init()
        var rateDownload: Int = 0
        var rateUpload: Int = 0
        var uploadRatio: Double = 0.0
        var downloadedEver: Int = 0
        var uploadedEver: Int = 0
        var totalSize: Int = 0
        var percentDone: Double = 0.0
        var eta: Int = 0
    }

    enum Action: Equatable {
        case updateSpeedSample(timestamp: Date, downloadRate: Int, uploadRate: Int)
        case resetSpeedHistory
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .updateSpeedSample(let timestamp, let downloadRate, let uploadRate):
                state.speedHistory.append(
                    timestamp: timestamp,
                    downloadRate: downloadRate,
                    uploadRate: uploadRate
                )
                state.rateDownload = downloadRate
                state.rateUpload = uploadRate
                return .none

            case .resetSpeedHistory:
                state.speedHistory.reset()
                return .none
            }
        }
    }
}
