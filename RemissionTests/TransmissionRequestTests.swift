import Foundation
import Testing

@testable import Remission

@Suite("TransmissionRequest")
struct TransmissionRequestTests {
    @Test("Кодирование формирует ожидаемую RPC-структуру без лишних полей")
    func encodingProducesTransmissionRPCShape() throws {
        // Этот тест фиксирует, что мы кодируем именно Transmission RPC,
        // а не JSON-RPC 2.0 (где есть поле jsonrpc).
        let request = TransmissionRequest(
            method: "torrent-get",
            arguments: .object([
                "fields": .array([.string("id"), .string("name")]),
                "ids": .array([.int(1), .int(2)])
            ]),
            tag: .int(99)
        )

        let data = try JSONEncoder().encode(request)
        let payloadAny = try JSONSerialization.jsonObject(with: data)
        let payload = try #require(payloadAny as? [String: Any])

        // Проверяем базовый контракт: method/arguments/tag присутствуют.
        #expect(payload["method"] as? String == "torrent-get")
        #expect(payload["tag"] as? Int == 99)
        #expect(payload["arguments"] != nil)

        // Критично: не должно появиться поле jsonrpc.
        #expect(payload["jsonrpc"] == nil)
    }

    @Test("Round-trip decode сохраняет method, arguments и строковый tag")
    func roundTripPreservesAllFields() throws {
        // Этот тест проверяет, что TransmissionTag корректно переживает Codable,
        // а AnyCodable не теряет вложенные аргументы.
        let original = TransmissionRequest(
            method: "session-set",
            arguments: .object([
                "speed-limit-down": .int(1024),
                "speed-limit-down-enabled": .bool(true)
            ]),
            tag: .string("req-1")
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionRequest.self, from: encoded)

        #expect(decoded == original)
    }
}
