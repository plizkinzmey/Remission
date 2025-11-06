import ComposableArchitecture
import Foundation

/// Конфигурация запуска приложения, позволяющая подготавливать состояние для UI-тестов.
enum AppBootstrap {
    /// Аргумент запуска, активирующий загрузку специальной фикстуры.
    private static let fixtureArgumentPrefix: String = "--ui-testing-fixture="

    /// Поддерживаемые UI фикстуры.
    enum UITestingFixture: String {
        case serverListSample = "server-list-sample"
    }

    /// Возвращает стартовое состояние приложения, учитывая аргументы процесса.
    static func makeInitialState(
        processInfo: ProcessInfo = .processInfo,
        targetVersion: AppStateVersion = .latest,
        existingState: AppReducer.State? = nil
    ) -> AppReducer.State {
        makeInitialState(
            arguments: processInfo.arguments,
            targetVersion: targetVersion,
            existingState: existingState
        )
    }

    /// Возвращает стартовое состояние приложения, учитывая переданные аргументы.
    static func makeInitialState(
        arguments: [String],
        targetVersion: AppStateVersion = .latest,
        existingState: AppReducer.State? = nil
    ) -> AppReducer.State {
        var state = existingState ?? AppReducer.State()
        migrate(&state, to: targetVersion)
        guard let fixture = parseFixture(from: arguments) else {
            return state
        }

        applyFixture(fixture, to: &state)
        return state
    }

    private static func parseFixture(from arguments: [String]) -> UITestingFixture? {
        guard let raw = arguments.first(where: { $0.hasPrefix(fixtureArgumentPrefix) }) else {
            return nil
        }
        let value = String(raw.dropFirst(fixtureArgumentPrefix.count))
        return UITestingFixture(rawValue: value)
    }

    private static func migrate(_ state: inout AppReducer.State, to targetVersion: AppStateVersion)
    {
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

    private static func applyFixture(_ fixture: UITestingFixture, to state: inout AppReducer.State)
    {
        switch fixture {
        case .serverListSample:
            state.serverList.servers = IdentifiedArrayOf(uniqueElements: [
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
            ])
        }
    }
}
