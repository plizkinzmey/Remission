import Foundation

enum TorrentCategory: String, CaseIterable, Equatable, Sendable {
    case programs
    case movies
    case series
    case books
    case other

    static let ordered: [TorrentCategory] = [
        .programs,
        .movies,
        .series,
        .books,
        .other
    ]

    var tagKey: String { rawValue }

    var title: String {
        switch self {
        case .programs:
            return L10n.tr("torrentCategory.programs")
        case .movies:
            return L10n.tr("torrentCategory.movies")
        case .series:
            return L10n.tr("torrentCategory.series")
        case .books:
            return L10n.tr("torrentCategory.books")
        case .other:
            return L10n.tr("torrentCategory.other")
        }
    }

    static func category(from tags: [String]) -> TorrentCategory {
        let normalized = Set(tags.map { $0.lowercased() })
        if normalized.contains(TorrentCategory.other.tagKey) {
            return .other
        }
        for category in TorrentCategory.ordered where category != .other {
            if normalized.contains(category.tagKey) {
                return category
            }
        }
        return .other
    }

    static func tags(for category: TorrentCategory) -> [String] {
        [category.tagKey]
    }
}
