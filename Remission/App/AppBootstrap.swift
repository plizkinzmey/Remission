import ComposableArchitecture
import Foundation

/// Конфигурация запуска приложения, позволяющая подготавливать состояние для UI-тестов.
enum AppBootstrap {
    // MARK: - Constants

    /// Аргумент запуска, активирующий загрузку специальной фикстуры.
    private static let fixtureArgumentPrefix: String = "--ui-testing-fixture="
    /// Аргумент, включающий специализированный сценарий UI-тестов (например, онбординг).
    private static let scenarioArgumentPrefix: String = "--ui-testing-scenario="
    /// Environment variable для UI-testing фикстуры.
    private static let fixtureEnvironmentKey: String = "UI_TESTING_FIXTURE"
    /// Environment variable для UI-testing сценария.
    private static let scenarioEnvironmentKey: String = "UI_TESTING_SCENARIO"
    /// Ключ Xcode для определения, что приложение запущено как UI-тест.
    private static let xcTestConfigurationKey: String = "XCTestConfigurationFilePath"

    /// Поддерживаемые UI фикстуры для предзагрузки тестового состояния приложения.
    ///
    /// Фикстуры используются для UI-тестов и обеспечивают предсказуемое состояние приложения.
    /// Пример использования в Xcode: "Edit Scheme" → "Run" → "Arguments Passed On Launch"
    /// и добавьте: `--ui-testing-fixture=server-list-sample`
    ///
    /// - Note: Фикстуры отключают загрузку серверов из репозитория и используют жёсткие данные
    enum UITestingFixture: String {
        /// Фикстура со списком предсконфигурированных серверов (локальный NAS + удалённый Seedbox).
        case serverListSample = "server-list-sample"
        /// Фикстура с одним сервером и списком образцовых торрентов (downloading, seeding, paused).
        case torrentListSample = "torrent-list-sample"
    }

    /// Набор предустановленных сценариев для UI-тестов.
    ///
    /// Сценарии управляют начальным потоком и навигацией приложения. Используйте вместе с фикстурами
    /// для полного контроля над состоянием приложения в начале теста.
    /// Пример: `--ui-testing-scenario=onboarding-flow`
    enum UITestingScenario: String {
        /// Сценарий онбординга: приложение запускается с нуля (нет сохранённых серверов).
        case onboardingFlow = "onboarding-flow"
        /// Сценарий списка серверов: приложение открывает экран со списком серверов.
        case serverListSample = "server-list-sample"
        /// Сценарий списка торрентов: приложение открывает первый сервер и показывает торренты.
        case torrentListSample = "torrent-list-sample"
        /// Сценарий оффлайн режима: приложение открывает сервер, но соединение недоступно.
        case torrentListOffline = "torrent-list-offline"
        /// Сценарий диагностики: приложение открывает экран диагностики и логов.
        case diagnosticsSample = "diagnostics-sample"
    }

    /// Возвращает стартовое состояние приложения, учитывая аргументы процесса.
    static func makeInitialState(
        processInfo: ProcessInfo = .processInfo,
        targetVersion: AppStateVersion = .latest,
        existingState: AppReducer.State? = nil,
        storageFileURL: URL = ServerConfigStoragePaths.defaultURL()
    ) -> AppReducer.State {
        makeInitialState(
            arguments: processInfo.arguments,
            environment: processInfo.environment,
            targetVersion: targetVersion,
            existingState: existingState,
            storageFileURL: storageFileURL
        )
    }

    /// Возвращает стартовое состояние приложения, учитывая переданные аргументы.
    static func makeInitialState(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment,
        targetVersion: AppStateVersion = .latest,
        existingState: AppReducer.State? = nil,
        storageFileURL: URL = ServerConfigStoragePaths.defaultURL()
    ) -> AppReducer.State {
        var state = existingState ?? AppReducer.State()
        performMigration(&state, to: targetVersion)
        applyTestingConfiguration(&state, from: arguments, environment: environment)
        return state
    }

    /// Выполняет миграцию состояния на целевую версию.
    /// - Parameters:
    ///   - state: Мутируемое состояние приложения
    ///   - targetVersion: Целевая версия состояния
    private static func performMigration(
        _ state: inout AppReducer.State,
        to targetVersion: AppStateVersion
    ) {
        migrate(&state, to: targetVersion)
    }

    /// Применяет конфигурацию UI-тестов (фикстуры и сценарии) к состоянию.
    /// - Parameters:
    ///   - state: Мутируемое состояние приложения
    ///   - arguments: Аргументы процесса из командной строки
    ///   - environment: Переменные окружения процесса
    private static func applyTestingConfiguration(
        _ state: inout AppReducer.State,
        from arguments: [String],
        environment: [String: String]
    ) {
        if let fixture = parseUITestFixture(arguments: arguments, environment: environment) {
            applyFixture(fixture, to: &state)
        }
    }

    static func parseUITestFixture(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestingFixture? {
        if let fixture = parseFixture(from: arguments) {
            return fixture
        }
        if let envValue = environment[fixtureEnvironmentKey] {
            return UITestingFixture(rawValue: envValue)
        }
        return nil
    }

    private static func parseFixture(from arguments: [String]) -> UITestingFixture? {
        guard let raw = arguments.first(where: { $0.hasPrefix(fixtureArgumentPrefix) }) else {
            return nil
        }
        let value = String(raw.dropFirst(fixtureArgumentPrefix.count))
        return UITestingFixture(rawValue: value)
    }

    static func parseUITestScenario(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestingScenario? {
        if let scenario = parseScenario(from: arguments) {
            return scenario
        }
        if let envValue = environment[scenarioEnvironmentKey] {
            return UITestingScenario(rawValue: envValue)
        }
        return nil
    }

    private static func parseScenario(from arguments: [String]) -> UITestingScenario? {
        guard let raw = arguments.first(where: { $0.hasPrefix(scenarioArgumentPrefix) }) else {
            return nil
        }
        let value = String(raw.dropFirst(scenarioArgumentPrefix.count))
        return UITestingScenario(rawValue: value)
    }

    private static func migrate(
        _ state: inout AppReducer.State,
        to targetVersion: AppStateVersion
    ) {
        guard state.version != targetVersion else { return }
        state.version = targetVersion
        state.path = .init()

        switch targetVersion {
        case .legacy:
            break
        case .v1:
            break
        @unknown default:
            assertionFailure("Unhandled AppStateVersion case: \(targetVersion)")
        }
    }

    private static func applyFixture(
        _ fixture: UITestingFixture,
        to state: inout AppReducer.State
    ) {
        switch fixture {
        case .serverListSample:
            state.serverList.servers = IdentifiedArrayOf(uniqueElements: serverListSampleServers())
            state.serverList.isPreloaded = true
            #if os(macOS)
                let isRunningUITests =
                    ProcessInfo.processInfo.environment[xcTestConfigurationKey] != nil
                let shouldAutoOpenFirstServer =
                    isRunningUITests && state.serverList.servers.isEmpty == false
                    && state.path.isEmpty
                if shouldAutoOpenFirstServer {
                    state.path.append(
                        ServerDetailReducer.State(server: state.serverList.servers[0]))
                }
            #endif
        case .torrentListSample:
            state.serverList.servers = IdentifiedArrayOf(
                uniqueElements: [torrentListSampleServer()]
            )
            state.serverList.isPreloaded = true
        @unknown default:
            assertionFailure("Unhandled UITestingFixture case: \(fixture)")
        }
    }

    static func serverListSampleServers() -> [ServerConfig] {
        let servers = [
            ServerConfig(
                id: makeFixedUUID("11111111-1111-1111-1111-111111111111"),
                name: "UI Test NAS",
                connection: .init(host: "nas.local", port: 9091),
                security: .http,
                authentication: .init(username: "admin")
            ),
            ServerConfig(
                id: makeFixedUUID("22222222-2222-2222-2222-222222222222"),
                name: "UI Test Seedbox",
                connection: .init(
                    host: "seedbox.example.com",
                    port: 443,
                    path: "/transmission/rpc"
                ),
                security: .https(allowUntrustedCertificates: false),
                authentication: .init(username: "seeduser")
            )
        ]
        assert(!servers.isEmpty, "Server list sample must contain at least one server")
        return servers
    }

    static func torrentListSampleServer() -> ServerConfig {
        var server = ServerConfig(
            name: "UI Torrent Fixture",
            connection: .init(
                host: "fixture.remission.test",
                port: 443,
                path: "/transmission/rpc"
            ),
            security: .https(allowUntrustedCertificates: true),
            authentication: .init(username: "uitester")
        )
        server.id = makeFixedUUID("AAAA1111-B222-C333-D444-EEEEEEEEEEEE")
        // Фиксированное время: 2024-01-01 04:00:00 UTC для детерминированных тестов
        server.createdAt = Date(timeIntervalSince1970: 1_704_000_000)
        return server
    }

    // MARK: - Helpers

    /// Создаёт UUID из строки с гарантией успеха для тестовых данных.
    /// Если строка невалидна как UUID, использует randomUUID() для предотвращения некорректного состояния.
    ///
    /// - Parameter uuidString: Строка в формате UUID (e.g., "11111111-1111-1111-1111-111111111111")
    /// - Returns: Инициализированный UUID или случайно сгенерированный при ошибке
    private static func makeFixedUUID(_ uuidString: String) -> UUID {
        guard let uuid = UUID(uuidString: uuidString) else {
            assertionFailure("Invalid UUID string: \(uuidString). Generated random UUID instead.")
            return UUID()
        }
        return uuid
    }

    static func torrentListSampleTorrents() -> [Torrent] {
        let torrents = [
            torrentListSampleDownloading(),
            torrentListSampleSeeding(),
            torrentListSamplePaused()
        ]
        assert(!torrents.isEmpty, "Torrent list sample must contain at least one torrent")
        return torrents
    }

    private static func torrentListSampleDownloading() -> Torrent {
        var downloading = Torrent.previewDownloading
        downloading.id = .init(rawValue: 1_001)
        downloading.name = "Ubuntu 25.04 Desktop"
        downloading.status = .downloading
        downloading.summary.progress.percentDone = 0.58
        downloading.summary.progress.downloadedEver = 9_100_000_000
        downloading.summary.progress.etaSeconds = 2_400
        downloading.summary.transfer.downloadRate = 3_500_000
        downloading.summary.transfer.uploadRate = 420_000
        return downloading
    }

    private static func torrentListSampleSeeding() -> Torrent {
        var seeding = Torrent.previewCompleted
        seeding.id = .init(rawValue: 1_002)
        seeding.name = "Fedora 41 Workstation"
        seeding.status = .seeding
        seeding.summary.transfer.uploadRate = 620_000
        return seeding
    }

    private static func torrentListSamplePaused() -> Torrent {
        var paused = Torrent.previewDownloading
        paused.id = .init(rawValue: 1_003)
        paused.name = "Arch Linux Snapshot"
        paused.status = .stopped
        paused.summary.progress.percentDone = 0.12
        paused.summary.transfer.downloadRate = 0
        paused.summary.transfer.uploadRate = 0
        paused.summary.progress.etaSeconds = -1
        return paused
    }
}
