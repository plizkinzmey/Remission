/// Represents a Transmission RPC response.
///
/// **Format**: Transmission RPC (NOT JSON-RPC 2.0)
/// - Uses `result`, `arguments`, and `tag` fields
/// - Does NOT include `jsonrpc` field or JSON-RPC error codes
/// - The `result` field is always a string: `"success"` on success or an error message on failure
///
/// Success example:
/// ```json
/// {
///   "result": "success",
///   "arguments": {
///     "torrents": [
///       {"id": 1, "name": "Ubuntu", "status": 4, "uploadRatio": 1.5}
///     ]
///   },
///   "tag": 1
/// }
/// ```
///
/// Error example:
/// ```json
/// {
///   "result": "too many recent requests",
///   "tag": 1
/// }
/// ```
///
/// - Parameters:
///   - result: The result status. `"success"` on success or an error message string on failure
///   - arguments: Optional method-specific response data
///   - tag: The tag from the corresponding request (if provided)
///
/// - Note: `Sendable` for thread-safe usage in async/await contexts
nonisolated(unsafe) public struct TransmissionResponse: Codable, Sendable {
    /// The result status of the request.
    ///
    /// On success, this will be the string `"success"`.
    /// On error, this contains the error message as a string (e.g., "too many recent requests").
    ///
    /// **Important**: Unlike JSON-RPC 2.0, Transmission RPC does NOT use numeric error codes.
    /// The error information is always a human-readable string.
    public let result: String

    /// Optional response data specific to the RPC method that was called.
    ///
    /// For example, a `torrent-get` response might include:
    /// ```swift
    /// "arguments": {
    ///   "torrents": [
    ///     {"id": 1, "name": "Ubuntu", "status": 4, ...}
    ///   ]
    /// }
    /// ```
    ///
    /// For methods that don't return data (like `torrent-start`), this may be nil or empty.
    public let arguments: AnyCodable?

    /// The tag from the corresponding request (if provided).
    /// Used to correlate async requests with their responses.
    public let tag: Int?

    /// Creates a new Transmission RPC response.
    ///
    /// - Parameters:
    ///   - result: The result status ("success" or error message)
    ///   - arguments: Optional response data
    ///   - tag: Optional tag from the request
    public init(result: String, arguments: AnyCodable? = nil, tag: Int? = nil) {
        self.result = result
        self.arguments = arguments
        self.tag = tag
    }

    // MARK: - Query Methods

    /// Returns `true` if the response indicates success.
    ///
    /// In Transmission RPC, success is indicated by `result == "success"`.
    public var isSuccess: Bool {
        result == "success"
    }

    /// Returns `true` if the response indicates an error.
    ///
    /// In Transmission RPC, any result other than `"success"` is an error.
    public var isError: Bool {
        !isSuccess
    }

    /// Returns the error message if this is an error response, otherwise nil.
    public var errorMessage: String? {
        isError ? result : nil
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case result
        case arguments
        case tag
    }
}

// MARK: - Equatable

nonisolated extension TransmissionResponse: Equatable {
    public static func == (lhs: TransmissionResponse, rhs: TransmissionResponse) -> Bool {
        lhs.result == rhs.result && lhs.arguments == rhs.arguments && lhs.tag == rhs.tag
    }
}

// MARK: - Hashable

nonisolated extension TransmissionResponse: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(result)
        hasher.combine(arguments)
        hasher.combine(tag)
    }
}
