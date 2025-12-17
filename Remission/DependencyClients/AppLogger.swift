import Foundation
import Logging

#if canImport(ComposableArchitecture)
    import Dependencies
#endif

/// Уровни логирования в приложении.
public enum AppLogLevel: String, Sendable, Codable {
    case debug
    case info
    case warning
    case error
}

/// Обертка над механизмом логирования, пригодная для Dependency injection.
/// Поддерживает категории и безопасные метаданные.
public struct AppLogger: @unchecked Sendable {
    enum Kind {
        case live
        case noop
    }

    private var logger: Logger
    private var baseLabel: String
    private var category: String
    private var kind: Kind
    private var handlerFactory: @Sendable (String) -> LogHandler
    private var diagnosticsSink: (@Sendable (DiagnosticsLogEntry) -> Void)?

    public init(
        label: String = "app.remission",
        category: String = "app",
        diagnosticsSink: (@Sendable (DiagnosticsLogEntry) -> Void)? = nil
    ) {
        AppLogger.bootstrapIfNeeded()
        self.handlerFactory = { @Sendable label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }
        self.baseLabel = label
        self.category = category
        self.logger = Logger(label: "\(label).\(category)", factory: handlerFactory)
        self.kind = .live
        self.diagnosticsSink = diagnosticsSink
    }

    init(
        logger: Logger,
        label: String,
        category: String,
        kind: Kind,
        factory: @escaping @Sendable (String) -> LogHandler,
        diagnosticsSink: (@Sendable (DiagnosticsLogEntry) -> Void)? = nil
    ) {
        self.logger = logger
        self.baseLabel = label
        self.category = category
        self.kind = kind
        self.handlerFactory = factory
        self.diagnosticsSink = diagnosticsSink
    }

    public func debug(_ message: String, metadata: [String: String] = [:]) {
        log(.debug, message: message, metadata: metadata)
    }

    public func info(_ message: String, metadata: [String: String] = [:]) {
        log(.info, message: message, metadata: metadata)
    }

    public func warning(_ message: String, metadata: [String: String] = [:]) {
        log(.warning, message: message, metadata: metadata)
    }

    public func error(_ message: String, metadata: [String: String] = [:]) {
        log(.error, message: message, metadata: metadata)
    }

    public func withCategory(_ category: String) -> AppLogger {
        AppLogger(
            logger: Logger(label: "\(baseLabel).\(category)", factory: handlerFactory),
            label: baseLabel,
            category: category,
            kind: kind,
            factory: handlerFactory,
            diagnosticsSink: diagnosticsSink
        )
    }

    public var isNoop: Bool { kind == .noop }

    public func withDiagnosticsSink(
        _ sink: @escaping @Sendable (DiagnosticsLogEntry) -> Void
    ) -> AppLogger {
        AppLogger(
            logger: logger,
            label: baseLabel,
            category: category,
            kind: kind,
            factory: handlerFactory,
            diagnosticsSink: sink
        )
    }

    private func log(
        _ level: AppLogLevel,
        message: String,
        metadata: [String: String]
    ) {
        let swiftLogLevel: Logger.Level
        switch level {
        case .debug: swiftLogLevel = .debug
        case .info: swiftLogLevel = .info
        case .warning: swiftLogLevel = .warning
        case .error: swiftLogLevel = .error
        }

        var enriched = metadata
        enriched["category"] = category
        logger.log(
            level: swiftLogLevel,
            "\(message)",
            metadata: enriched.mapValues { .string($0) }
        )

        if let diagnosticsSink {
            var entryMetadata = enriched
            entryMetadata.removeValue(forKey: "category")
            let entry = DiagnosticsLogEntry(
                timestamp: Date(),
                level: level,
                message: message,
                category: category,
                metadata: entryMetadata
            )
            diagnosticsSink(entry)
        }
    }
}

extension AppLogger {
    /// Live logger that outputs to the configured `LoggingSystem`.
    public static let liveValue: AppLogger = AppLogger()
    /// No-op logger for tests and previews.
    public static let noop: AppLogger = AppLogger(
        logger: Logger(label: "app.remission.noop") { _ in SwiftLogNoOpLogHandler() },
        label: "app.remission",
        category: "app",
        kind: .noop,
        factory: { _ in SwiftLogNoOpLogHandler() }
    )

    private static func bootstrapIfNeeded() {
        _ = bootstrapToken
    }

    private static let bootstrapToken: Void = {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }
    }()
}

#if canImport(ComposableArchitecture)
    private enum AppLoggerKey: DependencyKey {
        static let liveValue: AppLogger = .liveValue
        static let testValue: AppLogger = .noop
        static let previewValue: AppLogger = .noop
    }

    extension DependencyValues {
        var appLogger: AppLogger {
            get { self[AppLoggerKey.self] }
            set { self[AppLoggerKey.self] = newValue }
        }
    }
#endif
