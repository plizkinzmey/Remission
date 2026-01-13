import Clocks
import ComposableArchitecture
import Dependencies
import Foundation

enum AppDependencies {
    /// Сборка live-набора зависимостей для основной Scheме приложения.
    static func makeLive() -> DependencyValues {
        var dependencies = DependencyValues.appDefault()
        dependencies.transmissionClient = .placeholder
        dependencies.userPreferencesRepository = .persistent()
        return dependencies
    }

    /// Набор зависимостей для SwiftUI превью.
    static func makePreview() -> DependencyValues {
        var dependencies = DependencyValues.appPreview()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        dependencies.userPreferencesRepository = .previewValue
        dependencies.offlineCacheRepository = .previewValue
        return dependencies
    }

    /// Базовый набор зависимостей для тестов (TestStore, unit).
    static func makeTestDefaults() -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        dependencies.userPreferencesRepository = .testValue
        dependencies.offlineCacheRepository = .testValue
        return dependencies
    }

    // Набор зависимостей для UI-тестов с управляемыми сценарием/фикстурой.
    // swiftlint:disable:next function_body_length
    static func makeUITest(
        fixture: AppBootstrap.UITestingFixture?,
        scenario: AppBootstrap.UITestingScenario?,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = CredentialsRepository.uiTestInMemory()
        dependencies.serverConfigRepository = .inMemory(initial: [])
        dependencies.onboardingProgressRepository = .inMemory()
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        dependencies.userPreferencesRepository = .testValue
        dependencies.offlineCacheRepository = .previewValue

        let resolvedScenario = resolveUITestScenario(fixture: fixture, scenario: scenario)

        switch resolvedScenario {
        case .onboardingFlow:
            dependencies.serverConnectionProbe = .uiTestOnboardingMock()
        case .serverListSample:
            dependencies.serverConfigRepository = .inMemory(
                initial: AppBootstrap.serverListSampleServers()
            )
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in }
            )
        case .torrentListSample, .torrentListOffline:
            let server = AppBootstrap.torrentListSampleServer()
            dependencies.serverConfigRepository = .inMemory(initial: [server])
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in }
            )
            if let key = server.credentialsKey {
                let credentials = TransmissionServerCredentials(
                    key: key,
                    password: "torrent-fixture-password"
                )
                dependencies.credentialsRepository = .uiTestInMemory(
                    initialCredentials: [key: credentials]
                )
            }
            let torrentStore = InMemoryTorrentRepositoryStore(
                torrents: AppBootstrap.torrentListSampleTorrents()
            )
            let baseRepository = TorrentRepository.inMemory(store: torrentStore)
            if resolvedScenario == .torrentListOffline {
                dependencies.torrentRepository = TorrentRepository(
                    fetchList: { throw APIError.networkUnavailable },
                    fetchDetails: { _ in throw APIError.networkUnavailable },
                    add: { _, _, _, _ in throw APIError.networkUnavailable },
                    start: { _ in throw APIError.networkUnavailable },
                    stop: { _ in throw APIError.networkUnavailable },
                    remove: { _, _ in throw APIError.networkUnavailable },
                    verify: { _ in throw APIError.networkUnavailable },
                    updateTransferSettings: { _, _ in throw APIError.networkUnavailable },
                    updateFileSelection: { _, _ in throw APIError.networkUnavailable }
                )
            } else {
                let fixtureRepository = TorrentRepository(
                    fetchList: {
                        try await Task.sleep(nanoseconds: 1_200_000_000)
                        return try await baseRepository.fetchList()
                    },
                    fetchDetails: { id in try await baseRepository.fetchDetails(id) },
                    add: { input, destination, startPaused, tags in
                        try await baseRepository.add(
                            input,
                            destinationPath: destination,
                            startPaused: startPaused,
                            tags: tags
                        )
                    },
                    start: { ids in try await baseRepository.start(ids) },
                    stop: { ids in try await baseRepository.stop(ids) },
                    remove: { ids, delete in
                        try await baseRepository.remove(ids, deleteLocalData: delete)
                    },
                    verify: { ids in try await baseRepository.verify(ids) },
                    updateTransferSettings: { settings, ids in
                        try await baseRepository.updateTransferSettings(settings, for: ids)
                    },
                    updateFileSelection: { updates, id in
                        try await baseRepository.updateFileSelection(updates, in: id)
                    }
                )
                dependencies.torrentRepository = fixtureRepository
            }
            let preferencesStore = InMemoryUserPreferencesRepositoryStore(
                preferences: UserPreferences(
                    pollingInterval: 2,
                    isAutoRefreshEnabled: true,
                    isTelemetryEnabled: false,
                    defaultSpeedLimits: .init(
                        downloadKilobytesPerSecond: nil,
                        uploadKilobytesPerSecond: nil
                    )
                )
            )
            dependencies.userPreferencesRepository = .inMemory(store: preferencesStore)
            let testClock = TestClock<Duration>()
            dependencies.appClock = .test(clock: testClock)
            let fixtureRepository: TorrentRepository
            if resolvedScenario == .torrentListOffline {
                fixtureRepository = TorrentRepository(
                    fetchList: { throw APIError.networkUnavailable },
                    fetchDetails: { _ in throw APIError.networkUnavailable },
                    add: { _, _, _, _ in throw APIError.networkUnavailable },
                    start: { _ in throw APIError.networkUnavailable },
                    stop: { _ in throw APIError.networkUnavailable },
                    remove: { _, _ in throw APIError.networkUnavailable },
                    verify: { _ in throw APIError.networkUnavailable },
                    updateTransferSettings: { _, _ in throw APIError.networkUnavailable },
                    updateFileSelection: { _, _ in throw APIError.networkUnavailable }
                )
            } else {
                fixtureRepository = TorrentRepository(
                    fetchList: {
                        try await Task.sleep(nanoseconds: 1_200_000_000)
                        return try await baseRepository.fetchList()
                    },
                    fetchDetails: { id in try await baseRepository.fetchDetails(id) },
                    add: { input, destination, startPaused, tags in
                        try await baseRepository.add(
                            input,
                            destinationPath: destination,
                            startPaused: startPaused,
                            tags: tags
                        )
                    },
                    start: { ids in try await baseRepository.start(ids) },
                    stop: { ids in try await baseRepository.stop(ids) },
                    remove: { ids, delete in
                        try await baseRepository.remove(ids, deleteLocalData: delete)
                    },
                    verify: { ids in try await baseRepository.verify(ids) },
                    updateTransferSettings: { settings, ids in
                        try await baseRepository.updateTransferSettings(settings, for: ids)
                    },
                    updateFileSelection: { updates, id in
                        try await baseRepository.updateFileSelection(updates, in: id)
                    }
                )
            }
            dependencies.torrentRepository = fixtureRepository
            let offlineCache = dependencies.offlineCacheRepository
            dependencies.serverConnectionEnvironmentFactory = .init { targetServer in
                guard targetServer.id == server.id else {
                    return try await ServerConnectionEnvironmentFactory.previewValue
                        .make(targetServer)
                }
                var transmissionClient = TransmissionClientDependency.placeholder
                transmissionClient.performHandshake = {
                    TransmissionHandshakeResult(
                        sessionID: "ui-fixture-session",
                        rpcVersion: 20,
                        minimumSupportedRpcVersion: 14,
                        serverVersionDescription: "Transmission 4.0.3 (UI Fixture)",
                        isCompatible: true
                    )
                }
                let credentialsFingerprint = OfflineCacheKey.credentialsFingerprint(
                    credentialsKey: targetServer.credentialsKey,
                    password: "torrent-fixture-password"
                )
                let cacheKey = OfflineCacheKey.make(
                    server: targetServer,
                    credentialsFingerprint: credentialsFingerprint,
                    rpcVersion: 20
                )
                return ServerConnectionEnvironment(
                    serverID: targetServer.id,
                    fingerprint: targetServer.connectionFingerprint,
                    dependencies: .init(
                        transmissionClient: transmissionClient,
                        torrentRepository: fixtureRepository,
                        sessionRepository: .placeholder
                    ),
                    cacheKey: cacheKey,
                    snapshot: offlineCache.client(cacheKey),
                    makeSnapshotClient: offlineCache.client
                )
            }
        case .diagnosticsSample:
            let now = Date()
            let entries: [DiagnosticsLogEntry] = [
                DiagnosticsLogEntry(
                    timestamp: now.addingTimeInterval(-120),
                    level: .info,
                    message: "Проверка состояния соединения",
                    category: "probe",
                    metadata: [
                        "status": "200",
                        "elapsed_ms": "45",
                        "server": "local"
                    ]
                ),
                DiagnosticsLogEntry(
                    timestamp: now.addingTimeInterval(-60),
                    level: .warning,
                    message: "Повторная попытка запроса",
                    category: "rpc",
                    metadata: [
                        "method": "session-get",
                        "status": "503",
                        "elapsed_ms": "230",
                        "host": "nas.local"
                    ]
                ),
                DiagnosticsLogEntry(
                    timestamp: now,
                    level: .error,
                    message: "Не удалось связаться с сервером",
                    category: "transmission",
                    metadata: [
                        "method": "torrent-get",
                        "error": "URLError.notConnectedToInternet(-1009)",
                        "host": "nas.local",
                        "retry_attempt": "1",
                        "max_retries": "3"
                    ]
                )
            ]
            let logStore = DiagnosticsLogStore.inMemory(initialEntries: entries, maxEntries: 3)
            dependencies.diagnosticsLogStore = logStore
            dependencies.appLogger = .noop
        case .none:
            break
        }

        if let defaults = resolveUITestPreferencesDefaults(environment: environment) {
            let shouldResetPreferences = environment["UI_TESTING_RESET_PREFERENCES"] == "1"
            dependencies.userPreferencesRepository = .persistent(
                defaults: defaults,
                resetStoredValue: shouldResetPreferences
            )
        }

        return dependencies
    }
}

private func resolveUITestScenario(
    fixture: AppBootstrap.UITestingFixture?,
    scenario: AppBootstrap.UITestingScenario?
) -> AppBootstrap.UITestingScenario? {
    if let scenario {
        return scenario
    }
    switch fixture {
    case .serverListSample:
        return .serverListSample
    case .torrentListSample:
        return .torrentListSample
    case .none:
        return nil
    }
}

private func resolveUITestPreferencesDefaults(environment: [String: String]) -> UserDefaults? {
    guard let suiteName = environment["UI_TESTING_PREFERENCES_SUITE"] else { return nil }
    return UserDefaults(suiteName: suiteName)
}

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

extension TransmissionServerCredentialsKey {
    static var preview: TransmissionServerCredentialsKey {
        TransmissionServerCredentialsKey(
            host: "preview.remote",
            port: 9091,
            isSecure: false,
            username: "remission-preview"
        )
    }
}

extension TransmissionServerCredentials {
    static var preview: TransmissionServerCredentials {
        TransmissionServerCredentials(
            key: .preview,
            password: "preview-password"
        )
    }
}

extension CredentialsRepository {
    /// In-memory реализация для UI-тестов, исключающая обращения к Keychain.
    static func uiTestInMemory(
        initialCredentials: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]
    ) -> CredentialsRepository {
        let store = UITestCredentialsStore(initial: initialCredentials)
        return CredentialsRepository(
            save: { credentials in
                await store.save(credentials)
            },
            load: { key in
                await store.load(key)
            },
            delete: { key in
                await store.delete(key)
            }
        )
    }
}

private actor UITestCredentialsStore {
    private var storage: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]

    init(initial: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]) {
        storage = initial
    }

    func save(_ credentials: TransmissionServerCredentials) {
        storage[credentials.key] = credentials
    }

    func load(_ key: TransmissionServerCredentialsKey) -> TransmissionServerCredentials? {
        storage[key]
    }

    func delete(_ key: TransmissionServerCredentialsKey) {
        storage[key] = nil
    }
}

extension CredentialsRepository {
    static func previewMock(
        load:
            @Sendable @escaping (TransmissionServerCredentialsKey) async throws ->
            TransmissionServerCredentials? = { _ in .preview },
        save: @Sendable @escaping (TransmissionServerCredentials) async throws -> Void = { _ in },
        delete: @Sendable @escaping (TransmissionServerCredentialsKey) async throws -> Void = { _ in
        }
    ) -> CredentialsRepository {
        CredentialsRepository(save: save, load: load, delete: delete)
    }
}

extension TransmissionClientDependency {
    static func previewMock(
        sessionGet: @Sendable @escaping () async throws -> TransmissionResponse = {
            TransmissionResponse(result: "success")
        }
    ) -> TransmissionClientDependency {
        var dependency = TransmissionClientDependency.placeholder
        dependency.sessionGet = sessionGet
        return dependency
    }
}
