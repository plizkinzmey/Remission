import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("AppBootstrap")
struct AppBootstrapTests {
    @Test("parseUITestFixture читает значение из аргументов")
    func parseFixtureFromArguments() {
        // Проверяем разбор аргумента --ui-testing-fixture.
        let arguments = ["--ui-testing-fixture=server-list-sample"]
        let fixture = AppBootstrap.parseUITestFixture(arguments: arguments, environment: [:])
        #expect(fixture == .serverListSample)
    }

    @Test("parseUITestFixture читает значение из окружения")
    func parseFixtureFromEnvironment() {
        // Значение из env должно работать, если аргументы не заданы.
        let environment = ["UI_TESTING_FIXTURE": "torrent-list-sample"]
        let fixture = AppBootstrap.parseUITestFixture(arguments: [], environment: environment)
        #expect(fixture == .torrentListSample)
    }

    @Test("parseUITestScenario читает значение из аргументов")
    func parseScenarioFromArguments() {
        // Проверяем разбор аргумента --ui-testing-scenario.
        let arguments = ["--ui-testing-scenario=onboarding-flow"]
        let scenario = AppBootstrap.parseUITestScenario(arguments: arguments, environment: [:])
        #expect(scenario == .onboardingFlow)
    }

    @Test("parseUITestScenario читает значение из окружения")
    func parseScenarioFromEnvironment() {
        // Значение из env должно приоритетно использоваться при отсутствии аргумента.
        let environment = ["UI_TESTING_SCENARIO": "diagnostics-sample"]
        let scenario = AppBootstrap.parseUITestScenario(arguments: [], environment: environment)
        #expect(scenario == .diagnosticsSample)
    }

    @Test("makeInitialState выполняет миграцию и очищает path")
    func makeInitialStateMigratesAndResetsPath() {
        // Миграция должна обновлять версию и сбрасывать navigation path.
        var state = AppReducer.State(version: .legacy)
        state.path.append(ServerDetailReducer.State(server: .previewLocalHTTP))

        let migrated = AppBootstrap.makeInitialState(
            arguments: [],
            environment: [:],
            targetVersion: .v1,
            existingState: state
        )

        #expect(migrated.version == .v1)
        #expect(migrated.path.isEmpty)
    }

    @Test("makeInitialState применяет serverListSample fixture")
    func makeInitialStateAppliesServerListFixture() {
        // Фикстура должна подставлять 2 сервера и помечать список как preload.
        let state = AppBootstrap.makeInitialState(
            arguments: ["--ui-testing-fixture=server-list-sample"],
            environment: [:]
        )

        #expect(state.serverList.isPreloaded)
        #expect(state.serverList.servers.count == 2)
        #expect(state.serverList.servers[0].name == "UI Test NAS")
    }

    @Test("makeInitialState применяет torrentListSample fixture")
    func makeInitialStateAppliesTorrentListFixture() {
        // Фикстура должна подставлять ровно один сервер.
        let state = AppBootstrap.makeInitialState(
            arguments: ["--ui-testing-fixture=torrent-list-sample"],
            environment: [:]
        )

        #expect(state.serverList.isPreloaded)
        #expect(state.serverList.servers.count == 1)
        #expect(state.serverList.servers[0].name == "UI Torrent Fixture")
    }
}
