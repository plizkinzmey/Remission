import ComposableArchitecture
import Foundation

extension TorrentListReducer {
    enum Filter: String, Equatable, CaseIterable, Hashable, Sendable {
        case all
        case downloading
        case seeding
        case errors

        var title: String {
            switch self {
            case .all: return L10n.tr("torrentList.filter.all")
            case .downloading: return L10n.tr("torrentList.filter.downloading")
            case .seeding: return L10n.tr("torrentList.filter.seeding")
            case .errors: return L10n.tr("torrentList.filter.errors")
            }
        }

        func matches(_ item: TorrentListItem.State) -> Bool {
            switch self {
            case .all:
                return true
            case .downloading:
                return [.downloading, .downloadWaiting, .checkWaiting, .checking]
                    .contains(item.torrent.status)
            case .seeding:
                return [.seeding, .seedWaiting].contains(item.torrent.status)
            case .errors:
                // Transmission помечает проблемные торренты статусом isolated.
                return item.torrent.status == .isolated
            }
        }
    }

    enum CategoryFilter: String, Equatable, CaseIterable, Hashable, Sendable {
        case all
        case programs
        case movies
        case series
        case books
        case other

        var title: String {
            switch self {
            case .all:
                return L10n.tr("torrentList.category.all")
            case .programs:
                return TorrentCategory.programs.title
            case .movies:
                return TorrentCategory.movies.title
            case .series:
                return TorrentCategory.series.title
            case .books:
                return TorrentCategory.books.title
            case .other:
                return TorrentCategory.other.title
            }
        }

        func matches(_ item: TorrentListItem.State) -> Bool {
            guard let category = mappedCategory else { return true }
            return TorrentCategory.category(from: item.torrent.tags) == category
        }

        private var mappedCategory: TorrentCategory? {
            switch self {
            case .all:
                return nil
            case .programs:
                return .programs
            case .movies:
                return .movies
            case .series:
                return .series
            case .books:
                return .books
            case .other:
                return .other
            }
        }
    }
}

extension TorrentListReducer.State {
    func filteredVisibleItems() -> IdentifiedArrayOf<TorrentListItem.State> {
        let query = normalizedSearchQuery
        // NOTE: при списках 1000+ элементов стоит кешировать результаты фильтра/сортировки,
        // сохраняя их в State и инвалидации через DiffID. Это избавит от лишних O(n log n)
        // пересчётов при каждом `body` и заметно разгрузит UI при больших библиотеках.
        let filtered = items.filter {
            selectedFilter.matches($0)
                && selectedCategory.matches($0)
                && matchesSearch($0, query: query)
        }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.id != rhs.id {
                return lhs.id.rawValue > rhs.id.rawValue
            }
            return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                == .orderedAscending
        }
        return IdentifiedArray(uniqueElements: sorted)
    }
}
