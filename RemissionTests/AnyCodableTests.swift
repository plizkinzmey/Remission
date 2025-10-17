import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

@Suite("AnyCodable")
nonisolated struct AnyCodableTests {
    @Test("Decode null value")
    nonisolated func decodeNull() throws {
        let json = "null"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .null)
    }

    @Test("Decode boolean values")
    nonisolated func decodeBoolean() throws {
        for value in [true, false] {
            let json = value ? "true" : "false"
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

            #expect(decoded == .bool(value))
        }
    }

    @Test("Decode integer value")
    nonisolated func decodeInteger() throws {
        let json = "42"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .int(42))
    }

    @Test("Decode double value")
    nonisolated func decodeDouble() throws {
        let json = "3.14"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .double(3.14))
    }

    @Test("Decode string value")
    nonisolated func decodeString() throws {
        let json = "\"hello world\""
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .string("hello world"))
    }

    @Test("Decode array value")
    nonisolated func decodeArray() throws {
        let json = "[1, 2, 3, \"four\"]"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let expected: AnyCodable = .array([.int(1), .int(2), .int(3), .string("four")])
        #expect(decoded == expected)
    }

    @Test("Decode object value")
    nonisolated func decodeObject() throws {
        let json = """
            {
              "name": "Ubuntu",
              "version": 20,
              "rating": 4.5,
              "active": true
            }
            """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        let expected: AnyCodable = .object([
            "name": .string("Ubuntu"),
            "version": .int(20),
            "rating": .double(4.5),
            "active": .bool(true)
        ])
        #expect(decoded == expected)
    }

    @Test("Encode null value")
    nonisolated func encodeNull() throws {
        let value: AnyCodable = .null
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "null")
    }

    @Test("Encode string value")
    nonisolated func encodeString() throws {
        let value: AnyCodable = .string("hello")
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "\"hello\"")
    }

    @Test("Encode array with mixed types")
    nonisolated func encodeArray() throws {
        let value: AnyCodable = .array([.int(1), .string("two"), .bool(false)])
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("1") && json.contains("two") && json.contains("false"))
    }

    @Test("Round-trip complex nested structure")
    nonisolated func roundTripComplex() throws {
        let original: AnyCodable = .object([
            "id": .int(1),
            "files": .array([
                .object(["name": .string("file1.txt"), "size": .int(1024)]),
                .object(["name": .string("file2.txt"), "size": .int(2048)])
            ]),
            "metadata": .object([
                "version": .int(3),
                "nullable": .null
            ])
        ])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)

        #expect(decoded == original)
    }
}

// swiftlint:enable explicit_type_interface
