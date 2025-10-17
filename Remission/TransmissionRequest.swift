/// Represents a Transmission RPC request.
///
/// **Format**: Transmission RPC (NOT JSON-RPC 2.0)
/// - Uses `method`, `arguments`, and `tag` fields
/// - Does NOT include `jsonrpc` field or JSON-RPC error codes
///
/// Example:
/// ```json
/// {
///   "method": "torrent-get",
///   "arguments": {
///     "fields": ["id", "name", "status"],
///     "ids": [1, 2, 3]
///   },
///   "tag": 1
/// }
/// ```
///
/// - Parameters:
///   - method: The RPC method name (e.g., "torrent-get", "session-set")
///   - arguments: Optional method-specific parameters as a generic dictionary
///   - tag: Optional client-generated tag that the server will echo back in the response
///
/// - Note: `Sendable` for thread-safe usage in async/await contexts
nonisolated(unsafe) public struct TransmissionRequest: Codable, Sendable {
    /// The name of the RPC method to invoke
    public let method: String

    /// Method-specific parameters. Can be an object with key-value pairs.
    /// The structure depends on the specific method being called.
    ///
    /// Example arguments for `torrent-get`:
    /// ```swift
    /// "arguments": {
    ///   "fields": ["id", "name", "status", "uploadRatio"],
    ///   "ids": [1, 2, 3]
    /// }
    /// ```
    ///
    /// Example arguments for `session-set`:
    /// ```swift
    /// "arguments": {
    ///   "speed-limit-down": 1024,
    ///   "speed-limit-up": 256
    /// }
    /// ```
    public let arguments: AnyCodable?

    /// Optional tag to correlate requests and responses.
    /// The server will echo this tag back in the response.
    /// Useful for matching async requests with responses.
    /// Can be either a numeric or string tag depending on server implementation.
    public let tag: TransmissionTag?

    /// Creates a new Transmission RPC request.
    ///
    /// - Parameters:
    ///   - method: The RPC method name (e.g., "torrent-get", "session-set")
    ///   - arguments: Optional method-specific parameters
    ///   - tag: Optional tag to correlate with response
    public init(method: String, arguments: AnyCodable? = nil, tag: TransmissionTag? = nil) {
        self.method = method
        self.arguments = arguments
        self.tag = tag
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case method
        case arguments
        case tag
    }
}

// MARK: - Equatable

nonisolated extension TransmissionRequest: Equatable {
    public static func == (lhs: TransmissionRequest, rhs: TransmissionRequest) -> Bool {
        lhs.method == rhs.method && lhs.arguments == rhs.arguments && lhs.tag == rhs.tag
    }
}

// MARK: - Hashable

nonisolated extension TransmissionRequest: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(arguments)
        hasher.combine(tag)
    }
}
