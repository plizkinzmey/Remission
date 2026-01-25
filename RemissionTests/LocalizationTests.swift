import Foundation
import Testing

@testable import Remission

@Suite("Localization Tests")
struct LocalizationTests {
    // Проверяет безопасное поведение при отсутствии ключа:
    // функция должна вернуть сам ключ, а не пустую строку.
    @Test
    func missingKeyFallsBackToKey() {
        let key = "missing.key.\(UUID().uuidString)"
        let value = L10n.tr(key)
        #expect(value == key)
    }

    // Проверяет, что для известного ключа возвращается непустое значение.
    @Test
    func knownKeyReturnsNonEmptyValue() {
        let value = L10n.tr("common.ok")
        #expect(value.isEmpty == false)
    }
}
