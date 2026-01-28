import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Date Provider Dependency Tests")
struct DateProviderDependencyTests {
    // Проверяет, что now возвращает дату, близкую к текущему времени.
    @Test
    func nowIsCloseToCurrentTime() {
        let provider = DateProviderDependency.placeholder
        let before = Date()
        let value = provider.now()
        let after = Date()

        #expect(value >= before)
        #expect(value <= after)
    }
}
