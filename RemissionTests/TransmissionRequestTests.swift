import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

@Suite("TransmissionRequest")
@MainActor
struct TransmissionRequestTests {
    @Test("Create request with method only")
    func createRequestMethodOnly() {
        let request = TransmissionRequest(method: "session-get")

        #expect(request.method == "session-get")
        #expect(request.arguments == nil)
        #expect(request.tag == nil)
    }

    @Test("Create request with method and numeric tag")
    func createRequestWithNumericTag() {
        let request = TransmissionRequest(method: "torrent-get", tag: .int(1))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == nil)
        #expect(request.tag == .int(1))
    }

    @Test("Create request with method and string tag")
    func createRequestWithStringTag() {
        let request = TransmissionRequest(method: "torrent-get", tag: .string("req-1"))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == nil)
        #expect(request.tag == .string("req-1"))
    }

    @Test("Create request with arguments")
    func createRequestWithArguments() {
        let arguments: AnyCodable = .object([
            "fields": .array([.string("id"), .string("name"), .string("status")]),
            "ids": .array([.int(1), .int(2)])
        ])
        let request = TransmissionRequest(method: "torrent-get", arguments: arguments, tag: .int(1))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == arguments)
        #expect(request.tag == .int(1))
    }

    @Test("Encode simple request with numeric tag")
    func encodeSimpleRequest() throws {
        let request = TransmissionRequest(method: "session-get", tag: .int(1))
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["method"] as? String) == "session-get")
        #expect((json["tag"] as? Int) == 1)
        #expect(json["arguments"] == nil)
    }

    @Test("Encode request with string tag")
    func encodeRequestWithStringTag() throws {
        let request = TransmissionRequest(method: "session-get", tag: .string("session-1"))
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["method"] as? String) == "session-get")
        #expect((json["tag"] as? String) == "session-1")
        #expect(json["arguments"] == nil)
    }

    @Test("Encode request with arguments")
    func encodeRequestWithArguments() throws {
        let arguments: AnyCodable = .object([
            "speed-limit-down": .int(1024),
            "speed-limit-up": .int(256)
        ])
        let request = TransmissionRequest(
            method: "session-set",
            arguments: arguments,
            tag: .int(2)
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["method"] as? String) == "session-set")
        #expect((json["tag"] as? Int) == 2)
        #expect(json["arguments"] != nil)
    }

    @Test("Decode simple request with numeric tag")
    func decodeSimpleRequest() throws {
        let json = """
            {
              "method": "torrent-start",
              "arguments": {"ids": [1, 2, 3]},
              "tag": 5
            }
            """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(TransmissionRequest.self, from: data)

        #expect(request.method == "torrent-start")
        #expect(request.tag == .int(5))
        #expect(request.arguments != nil)
    }

    @Test("Decode simple request with string tag")
    func decodeSimpleRequestStringTag() throws {
        let json = """
            {
              "method": "torrent-start",
              "arguments": {"ids": [1, 2, 3]},
              "tag": "req-5"
            }
            """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(TransmissionRequest.self, from: data)

        #expect(request.method == "torrent-start")
        #expect(request.tag == .string("req-5"))
        #expect(request.arguments != nil)
    }

    @Test("Round-trip request encoding/decoding with numeric tag")
    func roundTripRequest() throws {
        let arguments: AnyCodable = .object([
            "ids": .array([.int(1), .int(2)]),
            "fields": .array([.string("id"), .string("name"), .string("percentDone")])
        ])
        let original = TransmissionRequest(
            method: "torrent-get",
            arguments: arguments,
            tag: .int(10)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionRequest.self, from: encoded)

        #expect(decoded.method == original.method)
        #expect(decoded.arguments == original.arguments)
        #expect(decoded.tag == original.tag)
    }

    @Test("Round-trip request encoding/decoding with string tag")
    func roundTripRequestStringTag() throws {
        let arguments: AnyCodable = .object([
            "ids": .array([.int(1), .int(2)])
        ])
        let original = TransmissionRequest(
            method: "torrent-get",
            arguments: arguments,
            tag: .string("batch-request-1")
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionRequest.self, from: encoded)

        #expect(decoded.method == original.method)
        #expect(decoded.arguments == original.arguments)
        #expect(decoded.tag == original.tag)
    }
}

// swiftlint:enable explicit_type_interface
