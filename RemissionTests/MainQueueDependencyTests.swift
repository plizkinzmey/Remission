import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Main Queue Dependency Tests")
struct MainQueueDependencyTests {
    private final class FlagBox: @unchecked Sendable {
        var value: Bool = false
    }

    // Проверяет, что async выполняет блок на главном акторе.
    @Test
    func asyncExecutesOperation() async throws {
        let executor = MainQueueDependency.placeholder
        let box = FlagBox()

        executor.async {
            box.value = true
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(box.value)
    }

    // Проверяет, что asyncAfter в placeholder также выполняет блок.
    @Test
    func asyncAfterExecutesOperation() async throws {
        let executor = MainQueueDependency.placeholder
        let box = FlagBox()

        executor.asyncAfter(.milliseconds(10)) {
            box.value = true
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(box.value)
    }
}
