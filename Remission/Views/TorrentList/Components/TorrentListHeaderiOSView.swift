import ComposableArchitecture
import SwiftUI

struct TorrentListHeaderiOSView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title - now part of the sticky block
            TorrentListHeaderView(title: L10n.tr("torrentList.section.title"))

            // Storage Summary
            TorrentListStorageSummaryView(summary: store.storageSummary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Controls (Filter Segmented Control & Category Menu)
            TorrentListControlsView(store: store)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        // Give the category picker some breathing room so it doesn't sit on the fade-out edge of the sticky header.
        .padding(.bottom, 12)
    }
}

#if DEBUG
    #Preview {
        TorrentListHeaderiOSView(
            store: Store(
                initialState: TorrentListReducer.State(
                    connectionEnvironment: .preview(server: .previewLocalHTTP),
                    items: []
                )
            ) {
                TorrentListReducer()
            }
        )
    }
#endif
