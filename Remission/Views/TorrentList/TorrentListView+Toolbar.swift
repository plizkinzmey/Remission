import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

extension TorrentListView {
    #if os(macOS)
        var macOSToolbarControls: some View {
            HStack(spacing: 10) {
                Button {
                    store.send(.addTorrentButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("torrentlist_add_button")

                Divider()
                    .frame(height: 18)

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
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("torrentlist_search_field")
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 300, idealWidth: 420, maxWidth: 520)
            .frame(height: 34)
            .appToolbarPillSurface()
        }
    #endif

    #if os(iOS)
        var shouldShowSearchBar: Bool {
            if UIDevice.current.userInterfaceIdiom == .pad { return false }
            guard store.connectionEnvironment != nil else { return false }
            return store.visibleItems.isEmpty == false || store.searchQuery.isEmpty == false
        }
    #endif
}
