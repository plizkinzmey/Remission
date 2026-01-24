import ComposableArchitecture
import Foundation

extension TorrentListReducer {
    /// Возвращает список элементов, отфильтрованных и отсортированных согласно текущему состоянию.
    func filteredVisibleItems(state: State) -> IdentifiedArrayOf<TorrentListItem.State> {
        var items = state.items

        // 1. Фильтрация по статусу (Filter)
        items = applyStatusFilter(items, filter: state.selectedFilter)

        // 2. Фильтрация по категории (CategoryFilter)
        items = applyCategoryFilter(items, category: state.selectedCategory)

        // 3. Фильтрация по поисковому запросу
        items = applySearchFilter(items, query: state.searchQuery)

        // 4. Сортировка (SortOrder)
        return sortItems(items, order: state.sortOrder)
    }

    private func applyStatusFilter(
        _ items: IdentifiedArrayOf<TorrentListItem.State>,
        filter: Filter
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        switch filter {
        case .all:
            return items
        case .downloading:
            return items.filter {
                [.downloading, .downloadWaiting, .checkWaiting, .checking].contains(
                    $0.torrent.status)
            }
        case .seeding:
            return items.filter { [.seeding, .seedWaiting].contains($0.torrent.status) }
        case .errors:
            return items.filter { $0.torrent.status == .isolated }
        }
    }

    private func applyCategoryFilter(
        _ items: IdentifiedArrayOf<TorrentListItem.State>,
        category: CategoryFilter
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        switch category {
        case .all:
            return items
        case .programs, .movies, .series, .books, .other:
            // Используем логику самого CategoryFilter для проверки соответствия
            return items.filter { category.matches($0) }
        }
    }

    private func applySearchFilter(
        _ items: IdentifiedArrayOf<TorrentListItem.State>,
        query: String
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.torrent.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private func sortItems(
        _ items: IdentifiedArrayOf<TorrentListItem.State>,
        order: SortOrder
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        var sorted = items
        // Используем логику самого SortOrder для сравнения
        sorted.sort { order.areInIncreasingOrder(lhs: $0, rhs: $1) }
        return sorted
    }
}
