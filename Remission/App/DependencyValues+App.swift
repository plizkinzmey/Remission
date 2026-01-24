import ComposableArchitecture
import Dependencies
import Foundation

extension DependencyValues {
    /// Значения по умолчанию для рабочей сборки.
    static func appDefault() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        let logStore = DiagnosticsLogStore.live()
        dependencies.diagnosticsLogStore = logStore
        dependencies.appLogger = dependencies.appLogger.withDiagnosticsSink(logStore.makeSink())
        return dependencies
    }

    /// Набор значений для SwiftUI превью.
    static func appPreview() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        dependencies.appLogger = .noop
        dependencies.diagnosticsLogStore = .placeholder
        dependencies.appClock = .placeholder
        dependencies.mainQueueExecutor = .placeholder
        dependencies.dateProvider = .placeholder
        dependencies.uuidGenerator = .placeholder
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.transmissionTrustStoreClient = .placeholder
        dependencies.serverConnectionProbe = .placeholder
        return dependencies
    }

    /// Набор значений для тестов.
    static func appTest() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        dependencies.appLogger = .noop
        dependencies.diagnosticsLogStore = .inMemory()
        dependencies.appClock = .placeholder
        dependencies.mainQueueExecutor = .placeholder
        dependencies.dateProvider = .placeholder
        dependencies.uuidGenerator = .placeholder
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.transmissionTrustStoreClient = .placeholder
        dependencies.serverConnectionProbe = .placeholder
        return dependencies
    }

    /// Применяет дефолтные зависимости проекта.
    mutating func useAppDefaults() {
        appClock = AppClockDependency.liveValue
        mainQueueExecutor = MainQueueDependency.liveValue
        dateProvider = DateProviderDependency.liveValue
        uuidGenerator = UUIDGeneratorDependency.liveValue
        appLogger = AppLogger.liveValue
    }
}
