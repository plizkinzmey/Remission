import Foundation

/// Represents errors that can occur when communicating with the Transmission RPC API.
///
/// This enum provides a comprehensive set of error cases covering:
/// - Network connectivity issues
/// - Authentication failures
/// - Session management problems
/// - API version incompatibilities
/// - JSON decoding failures
/// - Unknown/unexpected errors
///
/// Each case can be mapped from HTTP status codes, Transmission RPC error strings,
/// or Swift `DecodingError` instances for consistent error handling across the application.
@frozen
public enum APIError: Error, Equatable {
    /// The network is unavailable (no internet connection).
    /// This occurs when the system cannot establish a network connection to reach the Transmission server.
    case networkUnavailable

    /// Authentication failed with the provided credentials.
    /// Typically mapped from HTTP 401 status code when username or password is incorrect.
    case unauthorized

    /// The Transmission session ID is invalid or expired.
    /// Mapped from HTTP 409 status code. The client should refresh the session ID and retry.
    case sessionConflict

    /// The Transmission daemon version is unsupported.
    /// Occurs when the server version is below the minimum required version (3.0+).
    /// Associated value contains the unsupported version string.
    case versionUnsupported(version: String)

    /// JSON decoding failed while parsing the Transmission RPC response.
    /// Associated value contains the decoding error details for debugging.
    case decodingFailed(underlyingError: String)

    /// An unknown or unexpected error occurred.
    /// This is a fallback for any error that doesn't fit into the categories above.
    /// Associated value contains the error description or HTTP status code for context.
    case unknown(details: String)
}

// MARK: - Error Mapping Helpers

// MARK: - Mapping Helpers

extension APIError {
    /// Maps HTTP status codes to corresponding `APIError` cases.
    ///
    /// - Parameter statusCode: The HTTP status code to map.
    /// - Returns: An `APIError` case matching the status code, or `.unknown` if no match is found.
    public nonisolated static func mapHTTPStatusCode(_ statusCode: Int) -> APIError {
        switch statusCode {
        case 401:
            return .unauthorized
        case 409:
            return .sessionConflict
        default:
            return .unknown(details: "HTTP status code: \(statusCode)")
        }
    }

    /// Maps Transmission RPC error strings to corresponding `APIError` cases.
    ///
    /// Transmission RPC returns error messages as strings in the `result` field.
    /// This function attempts to categorize those strings into appropriate error cases.
    ///
    /// - Parameter errorString: The error message returned by Transmission RPC.
    /// - Returns: An `APIError` case matching the error message, or `.unknown` if no specific match is found.
    public nonisolated static func mapTransmissionError(_ errorString: String) -> APIError {
        let lowerErrorString: String = errorString.lowercased()

        // Check for version-related errors
        if lowerErrorString.contains("version") || lowerErrorString.contains("rpc-version") {
            return .versionUnsupported(version: errorString)
        }

        // Check for decoding/parsing errors reported by Transmission
        let containsParsingError: Bool =
            lowerErrorString.contains("invalid json")
            || lowerErrorString.contains("parse")
            || lowerErrorString.contains("decode")

        if containsParsingError {
            return .decodingFailed(underlyingError: errorString)
        }

        // Check for authentication errors
        let containsAuthError: Bool =
            lowerErrorString.contains("auth")
            || lowerErrorString.contains("unauthorized")
            || lowerErrorString.contains("credential")

        if containsAuthError {
            return .unauthorized
        }

        // Check for session errors
        if lowerErrorString.contains("session") || lowerErrorString.contains("csrf") {
            return .sessionConflict
        }

        // Fallback for unrecognized error messages
        return .unknown(details: errorString)
    }

    /// Maps Swift `DecodingError` to corresponding `APIError`.
    ///
    /// This function inspects the decoding error and attempts to provide helpful
    /// context about what went wrong during JSON parsing.
    ///
    /// - Parameter error: The `DecodingError` to map.
    /// - Returns: An `.decodingFailed` error with details about the decoding failure.
    public nonisolated static func mapDecodingError(_ error: DecodingError) -> APIError {
        switch error {
        case .dataCorrupted(let context):
            return .decodingFailed(underlyingError: "Data corrupted: \(context.debugDescription)")

        case .keyNotFound(let key, let context):
            return .decodingFailed(
                underlyingError:
                    "Key not found: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
            )

        case .typeMismatch(let type, let context):
            return .decodingFailed(
                underlyingError:
                    "Type mismatch: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
            )

        case .valueNotFound(let type, let context):
            return .decodingFailed(
                underlyingError:
                    "Value not found: expected \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
            )

        @unknown default:
            return .decodingFailed(underlyingError: "Unknown decoding error: \(error)")
        }
    }

    /// Maps `URLError` (network-related errors) to corresponding `APIError`.
    ///
    /// - Parameter error: The `URLError` to map.
    /// - Returns: An appropriate `APIError` case for the network condition.
    public nonisolated static func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed,
            .secureConnectionFailed,
            .cannotLoadFromNetwork:
            return .networkUnavailable

        default:
            return .unknown(details: "URL error: \(error.localizedDescription)")
        }
    }
}
