/// A type-erased codable value that can represent any JSON-encodable/decodable value.
/// Used for Transmission RPC `arguments` field which can contain various data types.
///
/// This allows flexible serialization/deserialization of Transmission RPC requests and responses
/// without needing to know the exact structure at compile time.
@preconcurrency @frozen
public enum AnyCodable: Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])
}

// MARK: - Codable Conformance

extension AnyCodable: Codable {
    // swiftlint:disable explicit_type_interface
    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
    // swiftlint:enable explicit_type_interface
}

// MARK: - Equatable Conformance

extension AnyCodable: Equatable {
    // swiftlint:disable identifier_name
    nonisolated public static func == (a: AnyCodable, b: AnyCodable) -> Bool {
        switch (a, b) {
        case (.null, .null):
            return true
        case (.bool(let a), .bool(let b)):
            return a == b
        case (.int(let a), .int(let b)):
            return a == b
        case (.double(let a), .double(let b)):
            return a == b
        case (.string(let a), .string(let b)):
            return a == b
        case (.array(let a), .array(let b)):
            return a == b
        case (.object(let a), .object(let b)):
            return a == b
        default:
            return false
        }
    }
    // swiftlint:enable identifier_name
}

// MARK: - Hashable Conformance

extension AnyCodable: Hashable {
    nonisolated public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case .bool(let bool):
            hasher.combine(1)
            hasher.combine(bool)
        case .int(let int):
            hasher.combine(2)
            hasher.combine(int)
        case .double(let double):
            hasher.combine(3)
            hasher.combine(double)
        case .string(let string):
            hasher.combine(4)
            hasher.combine(string)
        case .array(let array):
            hasher.combine(5)
            hasher.combine(array)
        case .object(let object):
            hasher.combine(6)
            hasher.combine(object)
        }
    }
}

// MARK: - Convenience Accessors

extension AnyCodable {
    /// Returns the string value if this is a `.string` case, otherwise nil.
    ///
    /// Example:
    /// ```swift
    /// if let name = anyCodable.stringValue {
    ///     print("Name: \(name)")
    /// }
    /// ```
    nonisolated public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the integer value if this is an `.int` case, otherwise nil.
    ///
    /// Example:
    /// ```swift
    /// if let id = anyCodable.intValue {
    ///     print("ID: \(id)")
    /// }
    /// ```
    nonisolated public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the double value if this is a `.double` case, otherwise nil.
    nonisolated public var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the boolean value if this is a `.bool` case, otherwise nil.
    nonisolated public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the array value if this is an `.array` case, otherwise nil.
    ///
    /// Example:
    /// ```swift
    /// if let items = anyCodable.arrayValue {
    ///     for item in items {
    ///         print(item)
    ///     }
    /// }
    /// ```
    nonisolated public var arrayValue: [AnyCodable]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the object (dictionary) value if this is an `.object` case, otherwise nil.
    ///
    /// Example:
    /// ```swift
    /// if let dict = anyCodable.objectValue {
    ///     if let name = dict["name"]?.stringValue {
    ///         print("Name: \(name)")
    ///     }
    /// }
    /// ```
    nonisolated public var objectValue: [String: AnyCodable]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }
}
