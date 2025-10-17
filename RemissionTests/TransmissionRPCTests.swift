import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

// MARK: - AnyCodable Tests

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
            "active": .bool(true),
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
                .object(["name": .string("file2.txt"), "size": .int(2048)]),
            ]),
            "metadata": .object([
                "version": .int(3),
                "nullable": .null,
            ]),
        ])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)

        #expect(decoded == original)
    }
}

// MARK: - TransmissionRequest Tests

@Suite("TransmissionRequest")
nonisolated struct TransmissionRequestTests {
    @Test("Create request with method only")
    nonisolated func createRequestMethodOnly() {
        let request = TransmissionRequest(method: "session-get")

        #expect(request.method == "session-get")
        #expect(request.arguments == nil)
        #expect(request.tag == nil)
    }

    @Test("Create request with method and numeric tag")
    nonisolated func createRequestWithNumericTag() {
        let request = TransmissionRequest(method: "torrent-get", tag: .int(1))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == nil)
        #expect(request.tag == .int(1))
    }

    @Test("Create request with method and string tag")
    nonisolated func createRequestWithStringTag() {
        let request = TransmissionRequest(method: "torrent-get", tag: .string("req-1"))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == nil)
        #expect(request.tag == .string("req-1"))
    }

    @Test("Create request with arguments")
    nonisolated func createRequestWithArguments() {
        let arguments: AnyCodable = .object([
            "fields": .array([.string("id"), .string("name"), .string("status")]),
            "ids": .array([.int(1), .int(2)]),
        ])
        let request = TransmissionRequest(method: "torrent-get", arguments: arguments, tag: .int(1))

        #expect(request.method == "torrent-get")
        #expect(request.arguments == arguments)
        #expect(request.tag == .int(1))
    }

    @Test("Encode simple request with numeric tag")
    nonisolated func encodeSimpleRequest() throws {
        let request = TransmissionRequest(method: "session-get", tag: .int(1))
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["method"] as? String) == "session-get")
        #expect((json["tag"] as? Int) == 1)
        #expect(json["arguments"] == nil)
    }

    @Test("Encode request with string tag")
    nonisolated func encodeRequestWithStringTag() throws {
        let request = TransmissionRequest(method: "session-get", tag: .string("session-1"))
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["method"] as? String) == "session-get")
        #expect((json["tag"] as? String) == "session-1")
        #expect(json["arguments"] == nil)
    }

    @Test("Encode request with arguments")
    nonisolated func encodeRequestWithArguments() throws {
        let arguments: AnyCodable = .object([
            "speed-limit-down": .int(1024),
            "speed-limit-up": .int(256),
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
    nonisolated func decodeSimpleRequest() throws {
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
    nonisolated func decodeSimpleRequestStringTag() throws {
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
    nonisolated func roundTripRequest() throws {
        let arguments: AnyCodable = .object([
            "ids": .array([.int(1), .int(2)]),
            "fields": .array([.string("id"), .string("name"), .string("percentDone")]),
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
    nonisolated func roundTripRequestStringTag() throws {
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

// MARK: - TransmissionResponse Tests

@Suite("TransmissionResponse")
nonisolated struct TransmissionResponseTests {
    @Test("Create success response with numeric tag")
    nonisolated func createSuccessResponse() {
        let response = TransmissionResponse(result: "success", tag: .int(1))

        #expect(response.result == "success")
        #expect(response.isSuccess == true)
        #expect(response.isError == false)
        #expect(response.errorMessage == nil)
        #expect(response.tag == .int(1))
    }

    @Test("Create success response with string tag")
    nonisolated func createSuccessResponseStringTag() {
        let response = TransmissionResponse(result: "success", tag: .string("req-1"))

        #expect(response.result == "success")
        #expect(response.isSuccess == true)
        #expect(response.isError == false)
        #expect(response.errorMessage == nil)
        #expect(response.tag == .string("req-1"))
    }

    @Test("Create error response with numeric tag")
    nonisolated func createErrorResponseNumericTag() {
        let response = TransmissionResponse(result: "too many recent requests", tag: .int(1))

        #expect(response.result == "too many recent requests")
        #expect(response.isSuccess == false)
        #expect(response.isError == true)
        #expect(response.errorMessage == "too many recent requests")
    }

    @Test("Create error response with string tag")
    nonisolated func createErrorResponseStringTag() {
        let response = TransmissionResponse(result: "permission denied", tag: .string("delete-1"))

        #expect(response.result == "permission denied")
        #expect(response.isSuccess == false)
        #expect(response.isError == true)
        #expect(response.errorMessage == "permission denied")
    }

    @Test("Create response with arguments and numeric tag")
    nonisolated func createResponseWithArgumentsNumericTag() {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Ubuntu"),
                    "status": .int(4),
                    "uploadRatio": .double(1.5),
                ])
            ])
        ])
        let response = TransmissionResponse(result: "success", arguments: arguments, tag: .int(1))

        #expect(response.isSuccess == true)
        #expect(response.arguments == arguments)
    }

    @Test("Create response with arguments and string tag")
    nonisolated func createResponseWithArgumentsStringTag() {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Ubuntu"),
                    "status": .int(4),
                    "uploadRatio": .double(1.5),
                ])
            ])
        ])
        let response = TransmissionResponse(
            result: "success", arguments: arguments, tag: .string("torrents-1"))

        #expect(response.isSuccess == true)
        #expect(response.arguments == arguments)
    }

    @Test("Encode success response with numeric tag")
    nonisolated func encodeSuccessResponseNumericTag() throws {
        let arguments: AnyCodable = .object([
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.6"),
        ])
        let response = TransmissionResponse(result: "success", arguments: arguments, tag: .int(1))

        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["result"] as? String) == "success")
        #expect((json["tag"] as? Int) == 1)
        #expect(json["arguments"] != nil)
    }

    @Test("Encode success response with string tag")
    nonisolated func encodeSuccessResponseStringTag() throws {
        let arguments: AnyCodable = .object([
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.6"),
        ])
        let response = TransmissionResponse(
            result: "success", arguments: arguments, tag: .string("session-info"))

        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["result"] as? String) == "success")
        #expect((json["tag"] as? String) == "session-info")
        #expect(json["arguments"] != nil)
    }

    @Test("Decode success response with numeric tag")
    nonisolated func decodeSuccessResponseNumericTag() throws {
        let json = """
            {
              "result": "success",
              "arguments": {
                "torrents": [
                  {"id": 1, "name": "Ubuntu", "status": 4}
                ]
              },
              "tag": 1
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.isSuccess == true)
        #expect(response.tag == .int(1))
        #expect(response.arguments != nil)
    }

    @Test("Decode success response with string tag")
    nonisolated func decodeSuccessResponseStringTag() throws {
        let json = """
            {
              "result": "success",
              "arguments": {
                "torrents": [
                  {"id": 1, "name": "Ubuntu", "status": 4}
                ]
              },
              "tag": "get-torrents"
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.isSuccess == true)
        #expect(response.tag == .string("get-torrents"))
        #expect(response.arguments != nil)
    }

    @Test("Decode error response with numeric tag")
    nonisolated func decodeErrorResponseNumericTag() throws {
        let json = """
            {
              "result": "too many recent requests",
              "tag": 1
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.isError == true)
        #expect(response.errorMessage == "too many recent requests")
        #expect(response.tag == .int(1))
    }

    @Test("Decode error response with string tag")
    nonisolated func decodeErrorResponseStringTag() throws {
        let json = """
            {
              "result": "permission denied",
              "tag": "delete-torrent"
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.isError == true)
        #expect(response.errorMessage == "permission denied")
        #expect(response.tag == .string("delete-torrent"))
    }

    @Test("Round-trip response encoding/decoding with numeric tag")
    nonisolated func roundTripResponseNumericTag() throws {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Test"),
                    "percentDone": .double(0.75),
                ])
            ])
        ])
        let original = TransmissionResponse(result: "success", arguments: arguments, tag: .int(5))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionResponse.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("Round-trip response encoding/decoding with string tag")
    nonisolated func roundTripResponseStringTag() throws {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Test"),
                    "percentDone": .double(0.75),
                ])
            ])
        ])
        let original = TransmissionResponse(
            result: "success", arguments: arguments, tag: .string("batch-5"))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionResponse.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("Decode response without arguments and numeric tag")
    nonisolated func decodeResponseWithoutArgumentsNumericTag() throws {
        let json = """
            {
              "result": "success",
              "tag": 2
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.result == "success")
        #expect(response.arguments == nil)
        #expect(response.tag == .int(2))
    }

    @Test("Decode response without arguments and string tag")
    nonisolated func decodeResponseWithoutArgumentsStringTag() throws {
        let json = """
            {
              "result": "success",
              "tag": "verify-torrent"
            }
            """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TransmissionResponse.self, from: data)

        #expect(response.result == "success")
        #expect(response.arguments == nil)
        #expect(response.tag == .string("verify-torrent"))
    }
}

// swiftlint:enable explicit_type_interface
