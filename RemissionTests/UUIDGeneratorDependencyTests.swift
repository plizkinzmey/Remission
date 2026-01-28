import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("UUID Generator Dependency Tests")
struct UUIDGeneratorDependencyTests {
    // Проверяет, что генератор возвращает UUID и обычно дает разные значения.
    @Test
    func generatorProducesUUIDs() {
        let generator = UUIDGeneratorDependency.placeholder
        let first = generator.generate()
        let second = generator.generate()

        #expect(first.uuidString.isEmpty == false)
        #expect(second.uuidString.isEmpty == false)
        #expect(first != second)
    }
}
