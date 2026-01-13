import ComposableArchitecture
import Foundation

/// Конфигурация запуска приложения, позволяющая подготавливать состояние для UI-тестов.
enum AppBootstrap {
    /// Аргумент запуска, активирующий загрузку специальной фикстуры.
    private static let fixtureArgumentPrefix: String = "--ui-testing-fixture="
    /// Аргумент, включающий специализированный сценарий UI-тестов (например, онбординг).
    private static let scenarioArgumentPrefix: String = "--ui-testing-scenario="

    /// Поддерживаемые UI фикстуры.
    enum UITestingFixture: String {
        case serverListSample = "server-list-sample"
        case torrentListSample = "torrent-list-sample"
    }

    /// Набор предустановленных сценариев для UI-тестов.
    enum UITestingScenario: String {
        case onboardingFlow = "onboarding-flow"
        case serverListSample = "server-list-sample"
        case torrentListSample = "torrent-list-sample"
        case torrentListOffline = "torrent-list-offline"
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
        migrate(&state, to: targetVersion)
        if let fixture = parseUITestFixture(arguments: arguments, environment: environment) {
            applyFixture(fixture, to: &state)
        }
        if existingState == nil, state.serverList.shouldLoadServersFromRepository == false {
            state.hasLoadedServersOnce = true
        }
        return state
    }

    static func parseUITestFixture(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestingFixture? {
        if let fixture = parseFixture(from: arguments) {
            return fixture
        }
        if let envValue = environment["UI_TESTING_FIXTURE"] {
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

    static func parseUITestScenario(arguments: [String]) -> UITestingScenario? {
        parseScenario(from: arguments)
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
        }
    }

    private static func applyFixture(
        _ fixture: UITestingFixture,
        to state: inout AppReducer.State
    ) {
        switch fixture {
        case .serverListSample:
            state.serverList.servers = IdentifiedArrayOf(uniqueElements: serverListSampleServers())
            state.serverList.shouldLoadServersFromRepository = false
            #if os(macOS)
                let isRunningUITests =
                    ProcessInfo.processInfo.environment[
                        "XCTestConfigurationFilePath"
                    ] != nil
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
            state.serverList.shouldLoadServersFromRepository = false
        }
    }

    static func serverListSampleServers() -> [ServerConfig] {
        [
            ServerConfig(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                name: "UI Test NAS",
                connection: .init(host: "nas.local", port: 9091),
                security: .http,
                authentication: .init(username: "admin")
            ),
            ServerConfig(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
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
        server.id = UUID(uuidString: "AAAA1111-B222-C333-D444-EEEEEEEEEEEE") ?? server.id
        server.createdAt = Date(timeIntervalSince1970: 1_704_000_000)
        return server
    }

    static func torrentListSampleTorrents() -> [Torrent] {
        var downloading = Torrent.previewDownloading
        downloading.id = .init(rawValue: 1_001)
        downloading.name = "Ubuntu 25.04 Desktop"
        downloading.status = .downloading
        downloading.summary.progress.percentDone = 0.58
        downloading.summary.progress.downloadedEver = 9_100_000_000
        downloading.summary.progress.etaSeconds = 2_400
        downloading.summary.transfer.downloadRate = 3_500_000
        downloading.summary.transfer.uploadRate = 420_000

        var seeding = Torrent.previewCompleted
        seeding.id = .init(rawValue: 1_002)
        seeding.name = "Fedora 41 Workstation"
        seeding.status = .seeding
        seeding.summary.transfer.uploadRate = 620_000

        var paused = Torrent.previewDownloading
        paused.id = .init(rawValue: 1_003)
        paused.name = "Arch Linux Snapshot"
        paused.status = .stopped
        paused.summary.progress.percentDone = 0.12
        paused.summary.transfer.downloadRate = 0
        paused.summary.transfer.uploadRate = 0
        paused.summary.progress.etaSeconds = -1

        return [downloading, seeding, paused]
    }
}
