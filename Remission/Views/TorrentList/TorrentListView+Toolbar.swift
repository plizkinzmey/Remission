import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

extension TorrentListView {
    #if os(macOS)
        var macOSToolbarControls: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                TextField(
                    L10n.tr("torrentList.search.prompt"),
                    text: .init(
                        get: { store.searchQuery },
                        set: { store.send(.searchQueryChanged($0)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .foregroundStyle(.primary)
            }
            .accessibilityIdentifier("torrentlist_search_field")
            .frame(minWidth: 300, idealWidth: 420, maxWidth: 520)
        }
    #endif

    #if os(iOS)
        var shouldShowSearchBar: Bool {
            if UIDevice.current.userInterfaceIdiom == .pad { return false }
            guard store.connectionEnvironment != nil else { return false }
            return store.items.isEmpty == false || store.searchQuery.isEmpty == false
        }
    #endif
}
