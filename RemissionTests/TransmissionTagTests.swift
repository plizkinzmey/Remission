import Foundation
import Testing

@testable import Remission

@Suite("Transmission Tag Tests")
struct TransmissionTagTests {
    // Проверяет корректное кодирование и декодирование целочисленного тега.
    @Test
    func codableIntTagRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let original: TransmissionTag = .int(42)

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TransmissionTag.self, from: data)
        #expect(decoded == original)
    }

    // Проверяет корректное кодирование и декодирование строкового тега.
    @Test
    func codableStringTagRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let original: TransmissionTag = .string("req-1")

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TransmissionTag.self, from: data)
        #expect(decoded == original)
    }

    // Проверяет, что несовместимый тип (bool) приводит к ошибке декодирования.
    @Test
    func decodingInvalidTypeThrows() throws {
        let decoder = JSONDecoder()
        let data = Data("true".utf8)

        var didThrow = false
        do {
            _ = try decoder.decode(TransmissionTag.self, from: data)
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    // Проверяет различие int/string в сравнении и хэшировании.
    @Test
    func equalityAndHashingDistinguishCases() {
        let intTag: TransmissionTag = .int(1)
        let stringTag: TransmissionTag = .string("1")

        #expect(intTag != stringTag)
        #expect(Set([intTag, stringTag]).count == 2)
    }
}
