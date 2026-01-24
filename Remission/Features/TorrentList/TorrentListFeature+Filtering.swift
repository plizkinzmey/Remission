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

    enum SortOrder: String, Equatable, CaseIterable, Hashable, Sendable {
        case name
        case progress
        case downloadSpeed
        case eta

        var title: String {
            switch self {
            case .name: return L10n.tr("torrentList.sort.name")
            case .progress: return L10n.tr("torrentList.sort.progress")
            case .downloadSpeed: return L10n.tr("torrentList.sort.speed")
            case .eta: return L10n.tr("torrentList.sort.eta")
            }
        }

        func areInIncreasingOrder(
            lhs: TorrentListItem.State,
            rhs: TorrentListItem.State
        ) -> Bool {
            switch self {
            case .name:
                return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                    != .orderedDescending

            case .progress:
                if lhs.metrics.progressFraction == rhs.metrics.progressFraction {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhs.metrics.progressFraction > rhs.metrics.progressFraction

            case .downloadSpeed:
                let lhsSpeed = lhs.torrent.summary.transfer.downloadRate
                let rhsSpeed = rhs.torrent.summary.transfer.downloadRate
                if lhsSpeed == rhsSpeed {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhsSpeed > rhsSpeed

            case .eta:
                let lhsEta = lhs.metrics.etaSeconds > 0 ? lhs.metrics.etaSeconds : .max
                let rhsEta = rhs.metrics.etaSeconds > 0 ? rhs.metrics.etaSeconds : .max
                if lhsEta == rhsEta {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhsEta < rhsEta
            }
        }
    }

    func filteredVisibleItems(state: State) -> IdentifiedArrayOf<TorrentListItem.State> {
        let query = state.normalizedSearchQuery
        // NOTE: при списках 1000+ элементов стоит кешировать результаты фильтра/сортировки,
        // сохраняя их в State и инвалидации через DiffID. Это избавит от лишних O(n log n)
        // пересчётов при каждом `body` и заметно разгрузит UI при больших библиотеках.
        let filtered = state.items.filter {
            state.selectedFilter.matches($0)
                && state.selectedCategory.matches($0)
                && state.matchesSearch($0, query: query)
        }
        let sorted = filtered.sorted {
            state.sortOrder.areInIncreasingOrder(lhs: $0, rhs: $1)
        }
        return IdentifiedArray(uniqueElements: sorted)
    }
}
