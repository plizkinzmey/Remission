import Foundation

/// Ошибки преобразования Transmission DTO → доменные модели.
enum DomainMappingError: Error, Equatable, LocalizedError {
    case rpcError(result: String, context: String)
    case missingArguments(context: String)
    case missingField(field: String, context: String)
    case invalidType(field: String, expected: String, context: String)
    case invalidValue(field: String, description: String, context: String)
    case unsupportedStatus(rawValue: Int)
    case emptyCollection(context: String)

    var errorDescription: String? {
        switch self {
        case .rpcError(let result, let context):
            return "Transmission RPC \(context) завершился с ошибкой: \(result)"
        case .missingArguments(let context):
            return "Ответ Transmission \(context) не содержит arguments секции"
        case .missingField(let field, let context):
            return "В ответе Transmission \(context) отсутствует поле \"\(field)\""
        case .invalidType(let field, let expected, let context):
            return "Неверный тип поля \"\(field)\" в \(context) (ожидался \(expected))"
        case .invalidValue(let field, let description, let context):
            return "Недопустимое значение поля \"\(field)\" в \(context): \(description)"
        case .unsupportedStatus(let rawValue):
            return "Статус торрента с rawValue=\(rawValue) не поддерживается"
        case .emptyCollection(let context):
            return "Ответ Transmission \(context) не содержит данных"
        }
    }
}

/// Сырые данные сохранённого сервера Transmission из слоя хранения.
struct StoredServerConfigRecord: Equatable, Sendable, Codable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var path: String?
    var isSecure: Bool
    var username: String?
    var createdAt: Date?
}

/// Централизованный маппер Transmission DTO → доменные модели.
struct TransmissionDomainMapper: Sendable {}
