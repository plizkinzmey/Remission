import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

final class AppBootstrapTests: XCTestCase {
    func testParseFixtureFromArguments() {
        // Проверяем разбор аргумента --ui-testing-fixture.
        let arguments = ["--ui-testing-fixture=server-list-sample"]
        let fixture = AppBootstrap.parseUITestFixture(arguments: arguments, environment: [:])
        XCTAssertEqual(fixture, .serverListSample)
    }

    func testParseFixtureFromEnvironment() {
        // Значение из env должно работать, если аргументы не заданы.
        let environment = ["UI_TESTING_FIXTURE": "torrent-list-sample"]
        let fixture = AppBootstrap.parseUITestFixture(arguments: [], environment: environment)
        XCTAssertEqual(fixture, .torrentListSample)
    }

    func testParseScenarioFromArguments() {
        // Проверяем разбор аргумента --ui-testing-scenario.
        let arguments = ["--ui-testing-scenario=onboarding-flow"]
        let scenario = AppBootstrap.parseUITestScenario(arguments: arguments, environment: [:])
        XCTAssertEqual(scenario, .onboardingFlow)
    }

    func testParseScenarioFromEnvironment() {
        // Значение из env должно приоритетно использоваться при отсутствии аргумента.
        let environment = ["UI_TESTING_SCENARIO": "diagnostics-sample"]
        let scenario = AppBootstrap.parseUITestScenario(arguments: [], environment: environment)
        XCTAssertEqual(scenario, .diagnosticsSample)
    }

    func testMakeInitialStateAppliesServerListFixture() {
        // Фикстура должна подставлять 2 сервера и помечать список как preload.
        let state = AppBootstrap.makeInitialState(
            arguments: ["--ui-testing-fixture=server-list-sample"],
            environment: [:]
        )

        XCTAssertTrue(state.serverList.isPreloaded)
        XCTAssertEqual(state.serverList.servers.count, 2)
        XCTAssertEqual(state.serverList.servers[0].name, "UI Test NAS")
    }

    func testMakeInitialStateAppliesTorrentListFixture() {
        // Фикстура должна подставлять ровно один сервер.
        let state = AppBootstrap.makeInitialState(
            arguments: ["--ui-testing-fixture=torrent-list-sample"],
            environment: [:]
        )

        XCTAssertTrue(state.serverList.isPreloaded)
        XCTAssertEqual(state.serverList.servers.count, 1)
        XCTAssertEqual(state.serverList.servers[0].name, "UI Torrent Fixture")
    }

    func testMakeInitialStateMigratesAndResetsPath() {
        // Миграция должна обновлять версию и сбрасывать navigation path.
        var state = AppReducer.State(version: .legacy)
        state.path.append(.serverDetail(ServerDetailReducer.State(server: .previewLocalHTTP)))

        let migrated = AppBootstrap.makeInitialState(
            arguments: [],
            environment: [:],
            targetVersion: .v1,
            existingState: state
        )

        XCTAssertEqual(migrated.version, AppStateVersion.v1)
        XCTAssertTrue(migrated.path.isEmpty)
    }
}
