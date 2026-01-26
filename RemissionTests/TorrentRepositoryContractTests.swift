import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Contract")
struct TorrentRepositoryContractTests {
    @Test("placeholder возвращает пустой список и не падает на start")
    func placeholderAllowsFetchListAndStart() async throws {
        // Этот тест фиксирует поведение placeholder: он безопасен для превью и
        // не должен выбрасывать ошибки на простых действиях.
        let repository = TorrentRepository.placeholder
        let list = try await repository.fetchList()
        #expect(list.isEmpty)

        try await repository.start([.init(rawValue: 1)])
    }

    @Test("placeholder бросает ошибку на fetchDetails")
    func placeholderThrowsOnFetchDetails() async {
        // Контракт placeholder: методы, требующие реального бэкенда,
        // должны сообщать о неправильной конфигурации.
        let repository = TorrentRepository.placeholder

        do {
            _ = try await repository.fetchDetails(.init(rawValue: 1))
            Issue.record("Ожидали ошибку конфигурации, но fetchDetails прошёл")
        } catch {
            #expect(
                error.localizedDescription
                    == "TorrentRepository.fetchDetails is not configured for this environment."
            )
        }
    }

    @Test("unimplemented бросает ошибку на fetchList и start")
    func unimplementedThrowsForAllOperations() async {
        // Проверяем, что unimplemented действительно защищает от случайного вызова
        // в тестах и продакшен-конфигурации.
        let repository = TorrentRepository.unimplemented

        do {
            _ = try await repository.fetchList()
            Issue.record("Ожидали ошибку конфигурации, но fetchList прошёл")
        } catch {
            #expect(
                error.localizedDescription
                    == "TorrentRepository.fetchList is not configured for this environment."
            )
        }

        do {
            try await repository.start([.init(rawValue: 10)])
            Issue.record("Ожидали ошибку конфигурации, но start прошёл")
        } catch {
            #expect(
                error.localizedDescription
                    == "TorrentRepository.start is not configured for this environment."
            )
        }
    }
}
