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
}
