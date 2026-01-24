import ComposableArchitecture
import SwiftUI

#if DEBUG
    extension TorrentDetailReducer.State {
        static func preview() -> Self {
            var state = TorrentDetailReducer.State(
                torrentID: .init(rawValue: 1)
            )
            state.apply(.previewDownloading)
            return state
        }
    }
#endif
