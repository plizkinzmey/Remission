import ComposableArchitecture
import Foundation

extension TorrentListReducer.State {
    var visibleItems: IdentifiedArrayOf<TorrentListItem.State> {
        visibleItemsCache
    }
}

extension TorrentListReducer.State {
    var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matchesSearch(
        _ item: TorrentListItem.State,
        query: String
    ) -> Bool {
        guard query.isEmpty == false else { return true }
        return item.torrent.name.localizedCaseInsensitiveContains(query)
    }
}
