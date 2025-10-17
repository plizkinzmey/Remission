/// Represents a Transmission RPC tag, which can be either an integer or a string.
///
/// Transmission RPC allows tags to be of flexible types for request/response correlation.
/// This type handles both numeric and string tag formats gracefully.
///
/// Example:
/// ```json
/// {"method": "torrent-get", "tag": 1}        // numeric tag
/// {"method": "torrent-get", "tag": "req-1"}  // string tag
/// ```
@frozen
nonisolated(unsafe) public enum TransmissionTag: Sendable {
    case int(Int)
    case string(String)
}

// MARK: - Codable Conformance

nonisolated extension TransmissionTag: Codable {
    public init(from decoder: Decoder) throws {
        let container: SingleValueDecodingContainer = try decoder.singleValueContainer()

        if let intValue: Int = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue: String = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "TransmissionTag must be either an integer or a string"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container: SingleValueEncodingContainer = encoder.singleValueContainer()

        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Equatable Conformance

nonisolated extension TransmissionTag: Equatable {
    public static func == (lhs: TransmissionTag, rhs: TransmissionTag) -> Bool {
        switch (lhs, rhs) {
        case (.int(let lhsValue), .int(let rhsValue)):
            return lhsValue == rhsValue
        case (.string(let lhsValue), .string(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

// MARK: - Hashable Conformance

nonisolated extension TransmissionTag: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .int(let value):
            hasher.combine(0)
            hasher.combine(value)
        case .string(let value):
            hasher.combine(1)
            hasher.combine(value)
        }
    }
}
