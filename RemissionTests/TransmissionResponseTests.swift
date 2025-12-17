import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

@Suite("TransmissionResponse")
@MainActor
struct TransmissionResponseTests {
    @Test("Create success response with numeric tag")
    func createSuccessResponse() {
        let response = TransmissionResponse(result: "success", tag: .int(1))

        #expect(response.result == "success")
        #expect(response.isSuccess == true)
        #expect(response.isError == false)
        #expect(response.errorMessage == nil)
        #expect(response.tag == .int(1))
    }

    @Test("Create success response with string tag")
    func createSuccessResponseStringTag() {
        let response = TransmissionResponse(result: "success", tag: .string("req-1"))

        #expect(response.result == "success")
        #expect(response.isSuccess == true)
        #expect(response.isError == false)
        #expect(response.errorMessage == nil)
        #expect(response.tag == .string("req-1"))
    }

    @Test("Create error response with numeric tag")
    func createErrorResponseNumericTag() {
        let response = TransmissionResponse(result: "too many recent requests", tag: .int(1))

        #expect(response.result == "too many recent requests")
        #expect(response.isSuccess == false)
        #expect(response.isError == true)
        #expect(response.errorMessage == "too many recent requests")
    }

    @Test("Create error response with string tag")
    func createErrorResponseStringTag() {
        let response = TransmissionResponse(result: "permission denied", tag: .string("delete-1"))

        #expect(response.result == "permission denied")
        #expect(response.isSuccess == false)
        #expect(response.isError == true)
        #expect(response.errorMessage == "permission denied")
    }

    @Test("Create response with arguments and numeric tag")
    func createResponseWithArgumentsNumericTag() {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Ubuntu"),
                    "status": .int(4),
                    "uploadRatio": .double(1.5)
                ])
            ])
        ])
        let response = TransmissionResponse(result: "success", arguments: arguments, tag: .int(1))

        #expect(response.isSuccess == true)
        #expect(response.arguments == arguments)
    }

    @Test("Create response with arguments and string tag")
    func createResponseWithArgumentsStringTag() {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Ubuntu"),
                    "status": .int(4),
                    "uploadRatio": .double(1.5)
                ])
            ])
        ])
        let response = TransmissionResponse(
            result: "success", arguments: arguments, tag: .string("torrents-1"))

        #expect(response.isSuccess == true)
        #expect(response.arguments == arguments)
    }

    @Test("Encode success response with numeric tag")
    func encodeSuccessResponseNumericTag() throws {
        let arguments: AnyCodable = .object([
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.6")
        ])
        let response = TransmissionResponse(result: "success", arguments: arguments, tag: .int(1))

        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect((json["result"] as? String) == "success")
        #expect((json["tag"] as? Int) == 1)
        #expect(json["arguments"] != nil)
    }

    @Test("Encode success response with string tag")
    func encodeSuccessResponseStringTag() throws {
        let arguments: AnyCodable = .object([
            "rpc-version": .int(17),
            "rpc-version-minimum": .int(14),
            "version": .string("4.0.6")
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
    func decodeSuccessResponseNumericTag() throws {
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
    func decodeSuccessResponseStringTag() throws {
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
    func decodeErrorResponseNumericTag() throws {
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
    func decodeErrorResponseStringTag() throws {
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
    func roundTripResponseNumericTag() throws {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Test"),
                    "percentDone": .double(0.75)
                ])
            ])
        ])
        let original = TransmissionResponse(result: "success", arguments: arguments, tag: .int(5))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionResponse.self, from: encoded)

        #expect(decoded == original)
    }

    @Test("Round-trip response encoding/decoding with string tag")
    func roundTripResponseStringTag() throws {
        let arguments: AnyCodable = .object([
            "torrents": .array([
                .object([
                    "id": .int(1),
                    "name": .string("Test"),
                    "percentDone": .double(0.75)
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
    func decodeResponseWithoutArgumentsNumericTag() throws {
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
    func decodeResponseWithoutArgumentsStringTag() throws {
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
