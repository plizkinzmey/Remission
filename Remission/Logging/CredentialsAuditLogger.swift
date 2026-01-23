import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Описание сервера без чувствительных данных.
struct CredentialsServerDescriptor: Equatable, Sendable {
    var host: String
    var port: Int
    var isSecure: Bool
    var username: String

    init(key: TransmissionServerCredentialsKey) {
        self.host = key.host
        self.port = key.port
        self.isSecure = key.isSecure
        self.username = key.username
    }

    var scheme: String { isSecure ? "https" : "http" }

    /// Маскированный username (показывает первые и последние символы).
    var maskedUsername: String {
        DataMasker.mask(username)
    }

    var endpointDescription: String {
        "\(scheme)://\(host):\(port)"
    }
}

/// Событие аудита операций с credential.
enum CredentialsAuditEvent: Equatable, Sendable {
    case saveSucceeded(CredentialsServerDescriptor)
    case saveFailed(CredentialsServerDescriptor, String)
    case loadSucceeded(CredentialsServerDescriptor)
    case loadMissing(CredentialsServerDescriptor)
    case loadFailed(CredentialsServerDescriptor, String)
    case deleteSucceeded(CredentialsServerDescriptor)
    case deleteFailed(CredentialsServerDescriptor, String)

    func message() -> String {
        switch self {
        case .saveSucceeded(let descriptor):
            return "[Credentials] ✅ save succeeded for \(descriptor.endpointDescription)"
        case .saveFailed(let descriptor, let reason):
            return "[Credentials] ⚠️ save failed for \(descriptor.endpointDescription): \(reason)"
        case .loadSucceeded(let descriptor):
            return "[Credentials] ✅ load succeeded for \(descriptor.endpointDescription)"
        case .loadMissing(let descriptor):
            return "[Credentials] ℹ️ load returned empty for \(descriptor.endpointDescription)"
        case .loadFailed(let descriptor, let reason):
            return "[Credentials] ⚠️ load failed for \(descriptor.endpointDescription): \(reason)"
        case .deleteSucceeded(let descriptor):
            return "[Credentials] ✅ delete succeeded for \(descriptor.endpointDescription)"
        case .deleteFailed(let descriptor, let reason):
            return "[Credentials] ⚠️ delete failed for \(descriptor.endpointDescription): \(reason)"
        }
    }
}

/// Логгер аудита с маскировкой чувствительных данных.
struct CredentialsAuditLogger: Sendable {
    private var appLogger: AppLogger
    private var eventSink: (@Sendable (CredentialsAuditEvent) -> Void)?

    init(
        appLogger: AppLogger,
        eventSink: (@Sendable (CredentialsAuditEvent) -> Void)? = nil
    ) {
        self.appLogger = appLogger
        self.eventSink = eventSink
    }

    func callAsFunction(_ event: CredentialsAuditEvent) {
        let message: String = event.message()
        let descriptor: CredentialsServerDescriptor? = event.serverDescriptor
        let maskedUsername: String = descriptor?.maskedUsername ?? "<n/a>"
        let metadata: [String: String] = [
            "endpoint": descriptor?.endpointDescription ?? "<unknown>",
            "user": maskedUsername
        ]

        eventSink?(event)

        switch event {
        case .saveSucceeded, .loadSucceeded, .deleteSucceeded, .loadMissing:
            appLogger.info(message, metadata: metadata)
        case .saveFailed, .loadFailed, .deleteFailed:
            appLogger.warning(message, metadata: metadata)
        }
    }
}

extension CredentialsAuditLogger {
    static func live(appLogger: AppLogger) -> CredentialsAuditLogger {
        CredentialsAuditLogger(appLogger: appLogger.withCategory("credentials.audit"))
    }

    static let noop: CredentialsAuditLogger = CredentialsAuditLogger(appLogger: .noop)
}

extension CredentialsAuditEvent {
    fileprivate var serverDescriptor: CredentialsServerDescriptor? {
        switch self {
        case .saveSucceeded(let descriptor),
            .saveFailed(let descriptor, _),
            .loadSucceeded(let descriptor),
            .loadMissing(let descriptor),
            .loadFailed(let descriptor, _),
            .deleteSucceeded(let descriptor),
            .deleteFailed(let descriptor, _):
            return descriptor
        }
    }
}

#if canImport(ComposableArchitecture)
    private enum CredentialsAuditLoggerKey: DependencyKey {
        static var liveValue: CredentialsAuditLogger {
            @Dependency(\.appLogger) var appLogger
            return .live(appLogger: appLogger)
        }
        static let testValue: CredentialsAuditLogger = .noop
        static let previewValue: CredentialsAuditLogger = .noop
    }

    extension DependencyValues {
        var credentialsAuditLogger: CredentialsAuditLogger {
            get { self[CredentialsAuditLoggerKey.self] }
            set { self[CredentialsAuditLoggerKey.self] = newValue }
        }
    }
#endif
