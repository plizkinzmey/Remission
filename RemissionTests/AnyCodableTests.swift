import Foundation
import Testing

@testable import Remission

@Suite("AnyCodable")
struct AnyCodableTests {
    @Test("Декодирование поддерживает все базовые JSON-типы и аксессоры")
    func decodeAllPrimitiveTypesAndAccessors() throws {
        // Этот тест фиксирует контракт AnyCodable как «универсального JSON-контейнера».
        // Мы проверяем сразу два слоя:
        // 1) Корректный выбор case при декодировании (int vs double и т.д.).
        // 2) Работу удобных accessor-свойств (stringValue, intValue и т.п.).
        let json = """
            {
              "null": null,
              "bool": true,
              "int": 1,
              "double": 1.5,
              "string": "remission",
              "array": [1, "two"],
              "object": { "nested": "value" }
            }
            """

        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        // Проверяем, что конкретные значения попали в ожидаемые case'ы.
        #expect(decoded["null"] == .null)
        #expect(decoded["bool"] == .bool(true))
        #expect(decoded["int"] == .int(1))
        #expect(decoded["double"] == .double(1.5))
        #expect(decoded["string"] == .string("remission"))

        // Проверяем accessor'ы — это основной API, которым пользуются мапперы и репозитории.
        #expect(decoded["string"]?.stringValue == "remission")
        #expect(decoded["int"]?.intValue == 1)
        #expect(decoded["double"]?.doubleValue == 1.5)
        #expect(decoded["bool"]?.boolValue == true)

        // Дополнительно убеждаемся, что массив и объект тоже корректно декодируются.
        #expect(decoded["array"]?.arrayValue?.count == 2)
        #expect(decoded["object"]?.objectValue?["nested"]?.stringValue == "value")
    }

    @Test("Round-trip encode/decode сохраняет структуру вложенных данных")
    func roundTripPreservesNestedStructure() throws {
        // Этот тест защищает от регрессий в Codable-конформансе.
        // Если порядок проверки типов или кодирование изменятся, round-trip начнёт «ломать» данные.
        let original: AnyCodable = .object([
            "list": .array([.int(42), .string("answer")]),
            "flags": .object([
                "enabled": .bool(true),
                "ratio": .double(1.25)
            ])
        ])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("Equatable различает близкие по смыслу, но разные case'ы")
    func equatableDistinguishesCases() {
        // В Transmission RPC важно различать 1 (int) и 1.0 (double),
        // иначе можно отправить аргументы «не того типа».
        #expect(AnyCodable.int(1) != AnyCodable.double(1.0))
        #expect(AnyCodable.string("1") != AnyCodable.int(1))
    }
}
