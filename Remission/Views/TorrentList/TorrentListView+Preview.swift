import ComposableArchitecture
import SwiftUI

#if DEBUG
    #Preview("Torrent List - Loaded") {
        NavigationStack {
            TorrentListView(
                store: .preview(state: .previewLoaded())
            )
        }
    }

    #Preview("Torrent List - Loading") {
        NavigationStack {
            TorrentListView(
                store: .preview(state: .previewLoading())
            )
        }
    }

    #Preview("Torrent List - Empty") {
        NavigationStack {
            TorrentListView(
                store: .preview(state: .previewEmpty())
            )
        }
    }

    #Preview("Torrent List - Error") {
        NavigationStack {
            TorrentListView(
                store: .preview(state: .previewError())
            )
        }
    }
#endif
