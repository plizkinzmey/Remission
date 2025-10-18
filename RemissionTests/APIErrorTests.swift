import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

@Suite("APIError Mapping Tests")
struct APIErrorTests {
    // MARK: - HTTP Status Code Mapping Tests

    @Test("Maps HTTP 401 to unauthorized")
    func testHTTP401MapsToUnauthorized() {
        let error = APIError.mapHTTPStatusCode(401)
        #expect(error == .unauthorized)
    }

    @Test("Maps HTTP 409 to sessionConflict")
    func testHTTP409MapsToSessionConflict() {
        let error = APIError.mapHTTPStatusCode(409)
        #expect(error == .sessionConflict)
    }

    @Test("Maps unknown HTTP status codes to unknown error")
    func testUnknownHTTPStatusCodeMapsToUnknown() {
        let testCodes = [400, 403, 404, 500, 502, 503, 999]

        for code in testCodes {
            let error = APIError.mapHTTPStatusCode(code)
            if case .unknown = error {
                // Successfully matched unknown case
            } else {
                #expect(Bool(false), "Expected .unknown for status code \(code), got \(error)")
            }
        }
    }

    // MARK: - Transmission Error String Mapping Tests

    @Test("Maps version-related error strings to versionUnsupported")
    func testVersionErrorStringsMapToVersionUnsupported() {
        let versionErrors = [
            "rpc-version unsupported",
            "Version 2.0 is not supported",
            "RPC version mismatch"
        ]

        for errorString in versionErrors {
            let error = APIError.mapTransmissionError(errorString)
            #expect(
                error == .versionUnsupported(version: errorString),
                "Expected .versionUnsupported for '\(errorString)', got \(error)"
            )
        }
    }

    @Test("Maps auth-related error strings to unauthorized")
    func testAuthErrorStringsMapToUnauthorized() {
        let authErrors = [
            "Authentication failed",
            "Unauthorized access",
            "Invalid credentials",
            "Auth required"
        ]

        for errorString in authErrors {
            let error = APIError.mapTransmissionError(errorString)
            #expect(error == .unauthorized, "Expected .unauthorized for '\(errorString)'")
        }
    }

    @Test("Maps session-related error strings to sessionConflict")
    func testSessionErrorStringsMapToSessionConflict() {
        let sessionErrors = [
            "Session invalid",
            "CSRF protection: invalid session token",
            "session-id expired"
        ]

        for errorString in sessionErrors {
            let error = APIError.mapTransmissionError(errorString)
            #expect(error == .sessionConflict, "Expected .sessionConflict for '\(errorString)'")
        }
    }

    @Test("Maps unknown error strings to unknown error")
    func testUnknownErrorStringsMapToUnknown() {
        let unknownError = "Something went wrong with the torrent"
        let error = APIError.mapTransmissionError(unknownError)

        if case .unknown(details: let details) = error {
            #expect(details == unknownError)
        } else {
            #expect(Bool(false), "Expected .unknown for unrecognized error string, got \(error)")
        }
    }

    @Test("Handles case-insensitive error string matching")
    func testCaseInsensitiveErrorMatching() {
        let expectedMappings: [String: APIError] = [
            "AUTHENTICATION FAILED": .unauthorized,
            "Authorization Required": .unauthorized,
            "Session Expired": .sessionConflict,
            "VERSION INCOMPATIBLE": .versionUnsupported(version: "VERSION INCOMPATIBLE")
        ]

        for (errorString, expectedError) in expectedMappings {
            let error = APIError.mapTransmissionError(errorString)
            #expect(
                error == expectedError,
                "Expected \(expectedError) for '\(errorString)', got \(error)"
            )
        }
    }

    // MARK: - DecodingError Mapping Tests

    @Test("Maps DecodingError dataCorrupted to decodingFailed")
    func testDataCorruptedErrorMapsToDecodingFailed() {
        let context = DecodingError.Context(codingPath: [], debugDescription: "Invalid JSON format")
        let decodingError = DecodingError.dataCorrupted(context)

        let error = APIError.mapDecodingError(decodingError)
        if case .decodingFailed(let underlyingError) = error {
            #expect(underlyingError.contains("Data corrupted"))
        } else {
            #expect(Bool(false), "Expected .decodingFailed, got \(error)")
        }
    }

    @Test("Maps DecodingError keyNotFound to decodingFailed with key information")
    func testKeyNotFoundErrorMapsToDecodingFailed() {
        let codingKey = AnyCodingKey(stringValue: "result")
        let context = DecodingError.Context(
            codingPath: [codingKey],
            debugDescription: "Key 'result' not found"
        )
        let decodingError = DecodingError.keyNotFound(codingKey, context)

        let error = APIError.mapDecodingError(decodingError)
        if case .decodingFailed(let underlyingError) = error {
            #expect(underlyingError.contains("Key not found"))
            #expect(underlyingError.contains("result"))
        } else {
            #expect(Bool(false), "Expected .decodingFailed with key info, got \(error)")
        }
    }

    @Test("Maps DecodingError typeMismatch to decodingFailed with type information")
    func testTypeMismatchErrorMapsToDecodingFailed() {
        let codingKey = AnyCodingKey(stringValue: "torrents")
        let context = DecodingError.Context(
            codingPath: [codingKey],
            debugDescription: "Type mismatch: expected Array"
        )
        let decodingError = DecodingError.typeMismatch(Array<String>.self, context)

        let error = APIError.mapDecodingError(decodingError)
        if case .decodingFailed(let underlyingError) = error {
            #expect(underlyingError.contains("Type mismatch"))
        } else {
            #expect(Bool(false), "Expected .decodingFailed with type info, got \(error)")
        }
    }

    @Test("Maps DecodingError valueNotFound to decodingFailed")
    func testValueNotFoundErrorMapsToDecodingFailed() {
        let codingKey = AnyCodingKey(stringValue: "id")
        let context = DecodingError.Context(
            codingPath: [codingKey],
            debugDescription: "Value not found for key 'id'"
        )
        let decodingError = DecodingError.valueNotFound(Int.self, context)

        let error = APIError.mapDecodingError(decodingError)
        if case .decodingFailed(let underlyingError) = error {
            #expect(underlyingError.contains("Value not found"))
        } else {
            #expect(Bool(false), "Expected .decodingFailed with value info, got \(error)")
        }
    }

    // MARK: - URLError Mapping Tests

    @Test("Maps notConnectedToInternet URLError to networkUnavailable")
    func testNotConnectedToInternetMapsToNetworkUnavailable() {
        let urlError = URLError(.notConnectedToInternet)
        let error = APIError.mapURLError(urlError)

        #expect(error == .networkUnavailable)
    }

    @Test("Maps networkConnectionLost URLError to networkUnavailable")
    func testNetworkConnectionLostMapsToNetworkUnavailable() {
        let urlError = URLError(.networkConnectionLost)
        let error = APIError.mapURLError(urlError)

        #expect(error == .networkUnavailable)
    }

    @Test("Maps other URLErrors to unknown error")
    func testOtherURLErrorsMapsToUnknown() {
        let testErrors: [URLError.Code] = [
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost
        ]

        for errorCode in testErrors {
            let urlError = URLError(errorCode)
            let error = APIError.mapURLError(urlError)
            if case .unknown = error {
                // Successfully mapped to unknown case
            } else {
                #expect(Bool(false), "Expected .unknown for URLError.\(errorCode), got \(error)")
            }
        }
    }

    // MARK: - Error Equatability Tests

    @Test("APIError.networkUnavailable conforms to Equatable")
    func testNetworkUnavailableEquatable() {
        let error1 = APIError.networkUnavailable
        let error2 = APIError.networkUnavailable

        #expect(error1 == error2)
    }

    @Test("APIError.unauthorized conforms to Equatable")
    func testUnauthorizedEquatable() {
        let error1 = APIError.unauthorized
        let error2 = APIError.unauthorized

        #expect(error1 == error2)
        #expect(error1 != .networkUnavailable)
    }

    @Test("APIError.sessionConflict conforms to Equatable")
    func testSessionConflictEquatable() {
        let error1 = APIError.sessionConflict
        let error2 = APIError.sessionConflict

        #expect(error1 == error2)
        #expect(error1 != .unauthorized)
    }

    @Test("APIError.versionUnsupported with same version conforms to Equatable")
    func testVersionUnsupportedEquatable() {
        let error1 = APIError.versionUnsupported(version: "2.0")
        let error2 = APIError.versionUnsupported(version: "2.0")
        let error3 = APIError.versionUnsupported(version: "3.0")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("APIError.decodingFailed with same error message conforms to Equatable")
    func testDecodingFailedEquatable() {
        let error1 = APIError.decodingFailed(underlyingError: "JSON parse error")
        let error2 = APIError.decodingFailed(underlyingError: "JSON parse error")
        let error3 = APIError.decodingFailed(underlyingError: "Different error")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("APIError.unknown with same details conforms to Equatable")
    func testUnknownEquatable() {
        let error1 = APIError.unknown(details: "Something went wrong")
        let error2 = APIError.unknown(details: "Something went wrong")
        let error3 = APIError.unknown(details: "Different issue")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}

// MARK: - Helper Types for Testing

/// A simple `CodingKey` implementation for testing purposes.
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// swiftlint:enable explicit_type_interface
