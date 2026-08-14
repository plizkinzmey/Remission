import ComposableArchitecture
import Foundation

enum TransferLimitUpdate: Equatable {
    case download(TorrentRepository.TransferLimit)
    case upload(TorrentRepository.TransferLimit)
}
