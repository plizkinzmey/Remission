import Foundation
import Testing

@testable import Remission

@Suite("Torrent Category Tests")
struct TorrentCategoryTests {
    struct CategoryCase: Sendable {
        let tags: [String]
        let expected: TorrentCategory
    }

    // Проверяет стабильный порядок категорий: он используется в UI
    // и не должен случайно поменяться.
    @Test
    func orderedMatchesAllCasesInExpectedOrder() {
        #expect(TorrentCategory.ordered == [.programs, .movies, .series, .books, .other])
        #expect(TorrentCategory.ordered.count == TorrentCategory.allCases.count)
    }

    // Проверяет, что категория определяется по тегам без учета регистра,
    // а также что при наличии "other" она имеет наивысший приоритет.
    @Test(
        "Category detection from tags",
        arguments: [
            CategoryCase(tags: ["movies"], expected: .movies),
            CategoryCase(tags: ["MoViEs"], expected: .movies),
            CategoryCase(tags: ["books", "series"], expected: .series),
            CategoryCase(tags: ["programs", "other"], expected: .other),
            CategoryCase(tags: ["unknown"], expected: .other),
            CategoryCase(tags: [], expected: .other)
        ]
    )
    func categoryFromTags(case input: CategoryCase) {
        let result = TorrentCategory.category(from: input.tags)
        #expect(result == input.expected)
    }

    // Проверяет, что преобразование категории в набор тегов
    // всегда возвращает ровно один canonical tagKey.
    @Test
    func tagsForCategoryReturnsSingleCanonicalTag() {
        let tags = TorrentCategory.tags(for: .series)
        #expect(tags == ["series"])
    }

    // Проверяет локализацию по тегу: пробелы и регистр не влияют,
    // неизвестные теги возвращают nil.
    @Test
    func localizedTitleForTagHandlesWhitespaceCaseAndUnknownTags() {
        let known = TorrentCategory.localizedTitle(for: "  MOVIES ")
        #expect(known == TorrentCategory.movies.title)

        let unknown = TorrentCategory.localizedTitle(for: "not-a-category")
        #expect(unknown == nil)
    }
}
