import Testing

@testable import Remission

@Suite("App State Version Tests")
struct AppStateVersionTests {
    // Проверяет, что latest указывает на актуальную версию и входит в allCases.
    @Test
    func latestMatchesExpectedVersion() {
        #expect(AppStateVersion.latest == .v1)
        #expect(AppStateVersion.allCases.contains(AppStateVersion.latest))
    }

    // Проверяет стабильность rawValue для миграций/персистентности.
    @Test
    func rawValuesAreStable() {
        #expect(AppStateVersion.legacy.rawValue == 0)
        #expect(AppStateVersion.v1.rawValue == 1)
    }
}
