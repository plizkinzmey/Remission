import Foundation
import Testing

@testable import Remission

@Suite("Data Masker Tests")
struct DataMaskerTests {
    struct MaskCase: Sendable {
        let input: String
        let visibleCount: Int
        let expected: String
    }

    // Проверяет особые случаи для коротких строк: пустая строка и строки,
    // которые короче или равны порогу видимых символов с двух сторон.
    @Test(
        "Mask handles empty and short strings",
        arguments: [
            MaskCase(input: "", visibleCount: 1, expected: "<empty>"),
            MaskCase(input: "a", visibleCount: 1, expected: "••••"),
            MaskCase(input: "ab", visibleCount: 1, expected: "••••"),
            MaskCase(input: "abcd", visibleCount: 2, expected: "••••")
        ]
    )
    func maskHandlesShortStrings(input: MaskCase) {
        let result = DataMasker.mask(input.input, visibleCount: input.visibleCount)
        #expect(result == input.expected)
    }

    // Проверяет основной сценарий: маскирование оставляет первые и последние
    // символы, а середину заменяет на маркер.
    @Test
    func maskKeepsEdgesForLongStrings() {
        let result = DataMasker.mask("password", visibleCount: 1)
        #expect(result == "p••••d")
    }

    // Проверяет, что для Basic Auth схема сохраняется, а credentials
    // маскируются с visibleCount = 4.
    @Test
    func maskAuthHeaderForBasicSchemeMasksOnlyCredentials() {
        let header = "Basic dXNlcm5hbWU6cGFzc3dvcmQ="
        let result = DataMasker.maskAuthHeader(header)

        #expect(result.hasPrefix("Basic "))
        #expect(result.contains("••••"))
        #expect(result.contains("dXNl"))
        #expect(result.contains("cmQ="))
    }

    // Проверяет, что для не-Basic заголовков применяется общее маскирование
    // с более широким visibleCount, чтобы не потерять контекст в логах.
    @Test
    func maskAuthHeaderForNonBasicFallsBackToGenericMasking() {
        let header = "Bearer supersecrettokenvalue"
        let expected = DataMasker.mask(header, visibleCount: 4)
        let result = DataMasker.maskAuthHeader(header)

        #expect(result == expected)
    }

    // Проверяет защиту от некорректного формата Basic-заголовка:
    // если нет credentials, возвращается безопасная заглушка.
    @Test
    func maskAuthHeaderForMalformedBasicReturnsSafePlaceholder() {
        let header = "Basic"
        let expected = DataMasker.mask(header, visibleCount: 4)
        let result = DataMasker.maskAuthHeader(header)
        #expect(result == expected)
    }

    // Проверяет, что маскирование session id делегируется общему mask
    // с visibleCount = 4 для предсказуемого поведения.
    @Test
    func maskSessionIDDelegatesToMaskWithVisibleCountFour() {
        let sessionID = "1234567890abcdef"
        let expected = DataMasker.mask(sessionID, visibleCount: 4)
        let result = DataMasker.maskSessionID(sessionID)

        #expect(result == expected)
    }
}
