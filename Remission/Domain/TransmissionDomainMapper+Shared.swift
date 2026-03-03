import Foundation

extension TransmissionDomainMapper {
    func arguments(
        from response: TransmissionResponse,
        context: String
    ) throws -> [String: AnyCodable] {
        guard response.isSuccess else {
            throw DomainMappingError.rpcError(result: response.result, context: context)
        }
        return try requireArguments(from: response, context: context)
    }

    func requireArguments(
        from response: TransmissionResponse,
        context: String
    ) throws -> [String: AnyCodable] {
        guard let arguments = response.arguments else {
            throw DomainMappingError.missingArguments(context: context)
        }

        guard case .object(let dict) = arguments else {
            throw DomainMappingError.invalidType(
                field: "arguments",
                expected: "object",
                context: context
            )
        }

        return dict
    }

    func requireField(
        _ field: String,
        in dict: [String: AnyCodable],
        context: String
    ) throws -> AnyCodable {
        guard let value = dict[field] else {
            throw DomainMappingError.missingField(field: field, context: context)
        }
        return value
    }

    func requireInt(
        _ field: String,
        in dict: [String: AnyCodable],
        context: String
    ) throws -> Int {
        guard let value = intValue(field, in: dict) else {
            throw DomainMappingError.missingField(field: field, context: context)
        }
        return value
    }

    func requireString(
        _ field: String,
        in dict: [String: AnyCodable],
        context: String
    ) throws -> String {
        guard let value = stringValue(field, in: dict) else {
            throw DomainMappingError.missingField(field: field, context: context)
        }
        return value
    }

    func stringValue(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> String? {
        dict[field]?.stringValue
    }

    func intValue(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Int? {
        if let value = dict[field]?.intValue {
            return value
        }
        if let double = dict[field]?.doubleValue {
            return Int(double)
        }
        return nil
    }

    func int64Value(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Int64 {
        if let int = dict[field]?.intValue {
            return Int64(int)
        }
        if let double = dict[field]?.doubleValue {
            return Int64(double)
        }
        return 0
    }

    func doubleValue(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Double? {
        if let value = dict[field]?.doubleValue {
            return value
        }
        if let int = dict[field]?.intValue {
            return Double(int)
        }
        return nil
    }

    func boolValue(
        _ field: String,
        in dict: [String: AnyCodable]
    ) -> Bool? {
        dict[field]?.boolValue
    }

    func value(
        for aliases: [String],
        in dict: [String: AnyCodable]
    ) -> AnyCodable? {
        for key in aliases {
            if let value = dict[key] {
                return value
            }
        }
        return nil
    }

    func intValue(
        aliases: [String],
        in dict: [String: AnyCodable]
    ) -> Int? {
        guard let value = value(for: aliases, in: dict) else { return nil }
        if let int = value.intValue {
            return int
        }
        if let double = value.doubleValue {
            return Int(double)
        }
        return nil
    }

    func int64Value(
        aliases: [String],
        in dict: [String: AnyCodable]
    ) -> Int64 {
        guard let value = value(for: aliases, in: dict) else { return 0 }
        if let int = value.intValue {
            return Int64(int)
        }
        if let double = value.doubleValue {
            return Int64(double)
        }
        return 0
    }

    func doubleValue(
        aliases: [String],
        in dict: [String: AnyCodable]
    ) -> Double? {
        guard let value = value(for: aliases, in: dict) else { return nil }
        if let double = value.doubleValue {
            return double
        }
        if let int = value.intValue {
            return Double(int)
        }
        return nil
    }

    func boolValue(
        aliases: [String],
        in dict: [String: AnyCodable]
    ) -> Bool? {
        value(for: aliases, in: dict)?.boolValue
    }

    func stringValue(
        aliases: [String],
        in dict: [String: AnyCodable]
    ) -> String? {
        value(for: aliases, in: dict)?.stringValue
    }

    func decode<T: Decodable>(_ type: T.Type, from arguments: AnyCodable?) throws -> T {
        guard let arguments = arguments else {
            throw DomainMappingError.missingArguments(context: String(describing: T.self))
        }
        // Round-trip through JSON to leverage Decodable
        let normalizedArguments = normalizeKeysForDecoding(arguments)
        let data = try JSONEncoder().encode(normalizedArguments)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func normalizeKeysForDecoding(_ value: AnyCodable) -> AnyCodable {
        switch value {
        case .object(let object):
            let normalized = object.reduce(into: [String: AnyCodable]()) { partial, pair in
                partial[normalizedDecodingKey(pair.key)] = normalizeKeysForDecoding(pair.value)
            }
            return .object(normalized)
        case .array(let array):
            return .array(array.map { normalizeKeysForDecoding($0) })
        case .string, .int, .double, .bool, .null:
            return value
        }
    }

    private func normalizedDecodingKey(_ key: String) -> String {
        let replaced = key.replacingOccurrences(of: "-", with: "_")
        let parts = replaced.split(separator: "_")
        guard parts.count > 1 else { return replaced }
        let head = String(parts[0])
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        return head + tail
    }
}
