import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

@Suite("TransmissionTag")
@MainActor
struct TransmissionTagTests {
    @Test("Create integer tag")
    func createIntTag() {
        let tag: TransmissionTag = .int(42)
        #expect(tag == .int(42))
    }

    @Test("Create string tag")
    func createStringTag() {
        let tag: TransmissionTag = .string("batch-1")
        #expect(tag == .string("batch-1"))
    }

    @Test("Decode integer tag from JSON")
    func decodeIntTag() throws {
        let json = "42"
        let data = json.data(using: .utf8)!
        let tag = try JSONDecoder().decode(TransmissionTag.self, from: data)
        #expect(tag == .int(42))
    }

    @Test("Decode string tag from JSON")
    func decodeStringTag() throws {
        let json = "\"req-1\""
        let data = json.data(using: .utf8)!
        let tag = try JSONDecoder().decode(TransmissionTag.self, from: data)
        #expect(tag == .string("req-1"))
    }

    @Test("Encode integer tag to JSON")
    func encodeIntTag() throws {
        let tag: TransmissionTag = .int(42)
        let data = try JSONEncoder().encode(tag)
        let decoded = try JSONDecoder().decode(Int.self, from: data)
        #expect(decoded == 42)
    }

    @Test("Encode string tag to JSON")
    func encodeStringTag() throws {
        let tag: TransmissionTag = .string("session-1")
        let data = try JSONEncoder().encode(tag)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"session-1\"")
    }

    @Test("Equatable comparison for tags")
    func equatableComparison() {
        let intTag1: TransmissionTag = .int(1)
        let intTag2: TransmissionTag = .int(1)
        let intTag3: TransmissionTag = .int(2)
        let stringTag: TransmissionTag = .string("1")

        #expect(intTag1 == intTag2)
        #expect(intTag1 != intTag3)
        #expect(intTag1 != stringTag)
    }

    @Test("Hashable for tags")
    func hashableSupport() {
        let intTag1: TransmissionTag = .int(1)
        let intTag2: TransmissionTag = .int(1)
        let stringTag: TransmissionTag = .string("1")

        let set: Set<TransmissionTag> = [intTag1, stringTag]
        #expect(set.contains(intTag2))
        #expect(set.contains(stringTag))
        #expect(set.count == 2)
    }
}

// swiftlint:enable explicit_type_interface
