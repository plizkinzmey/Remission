import Dependencies
import Foundation
import Logging
import Testing

@testable import Remission

private struct AppLoggerTestRecord: Sendable {
    var level: Logger.Level
    var message: String
    var metadata: Logger.Metadata
}

private final class AppLoggerTestCollector: @unchecked Sendable, LogHandler {
    private var storage: [AppLoggerTestRecord] = []
    private let lock = NSLock()

    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        lock.lock()
        storage.append(
            .init(
                level: level,
                message: message.description,
                metadata: metadata ?? [:]
            )
        )
        lock.unlock()
    }

    var records: [AppLoggerTestRecord] {
        lock.lock()
        let result = storage
        lock.unlock()
        return result
    }
}

@Suite("AppLogger Tests")
struct AppLoggerTests {
    @Test("Live logger пишет метаданные и категорию")
    func testLiveLoggerWritesMetadata() throws {
        let collector = AppLoggerTestCollector()
        let logger = AppLogger(
            logger: Logger(label: "test.logger") { _ in collector },
            label: "test.logger",
            category: "net",
            kind: .live,
            factory: { @Sendable _ in collector }
        )

        logger.info("hello", metadata: ["key": "value"])

        let records = collector.records
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.level == .info)
        #expect(record.message.contains("hello"))
        #expect(record.metadata["key"] == "value")
        #expect(record.metadata["category"] == "net")
    }

    @Test("withCategory создает новый логгер с новой категорией")
    func testWithCategoryCreatesNewCategory() throws {
        let collector = AppLoggerTestCollector()
        let base = AppLogger(
            logger: Logger(label: "test.logger") { _ in collector },
            label: "test.logger",
            category: "base",
            kind: .live,
            factory: { @Sendable _ in collector }
        )

        let derived = base.withCategory("feature")
        derived.debug("ping")

        let record = try #require(collector.records.first)
        #expect(record.metadata["category"] == "feature")
    }

    @Test("Dependency values используют noop в тестах/preview")
    func testDependencyDefaults() {
        let liveDeps = DependencyValues.appDefault()
        #expect(liveDeps.appLogger.isNoop == false)

        let previewDeps = DependencyValues.appPreview()
        #expect(previewDeps.appLogger.isNoop == true)

        let testDeps = DependencyValues.appTest()
        #expect(testDeps.appLogger.isNoop == true)
    }

    @Test("Live appLogger пишет в diagnosticsLogStore")
    func testDiagnosticsSinkCapturesLogs() async throws {
        let deps = DependencyValues.appDefault()
        var iterator = await deps.diagnosticsLogStore.observe(.init()).makeAsyncIterator()
        _ = await iterator.next()

        deps.appLogger
            .withCategory("diagnostics.test")
            .info("Hello diagnostics", metadata: ["k": "v"])

        let entries = try #require(await iterator.next())
        let entry = try #require(entries.first)
        #expect(entry.message == "Hello diagnostics")
        #expect(entry.category == "diagnostics.test")
        #expect(entry.level == .info)
        #expect(entry.metadata["k"] == "v")
    }
}
