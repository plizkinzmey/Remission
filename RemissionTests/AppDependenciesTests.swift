import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

final class AppDependenciesTests: XCTestCase {
    func testAppPreviewUsesNoopLoggerAndPreviewCredentials() async throws {
        // Проверяем, что preview окружение не пишет реальные логи
        // и использует предсказуемые креды.
        let dependencies = AppDependencies.makePreview()
        XCTAssertTrue(dependencies.appLogger.isNoop)

        let credentials = try await dependencies.credentialsRepository.load(key: .preview)
        XCTAssertEqual(credentials?.password, "preview-password")
    }

    func testAppTestUsesNoopLogger() async throws {
        // Тестовое окружение должно быть максимально безопасным и детерминированным.
        let dependencies = AppDependencies.makeTestDefaults()
        XCTAssertTrue(dependencies.appLogger.isNoop)

        let entries = try await dependencies.diagnosticsLogStore.load(.init())
        XCTAssertTrue(entries.isEmpty)
    }

    func testMakeLiveBuildsIsolatedEnvironment() async throws {
        let namespace = AppStorageNamespace.unitTesting(id: UUID())
        let dependencies = AppDependencies.makeLive(namespace: namespace)
        let servers = try await dependencies.serverConfigRepository.load()

        XCTAssertTrue(servers.isEmpty)
        XCTAssertTrue(namespace.applicationSupportDirectoryName.hasPrefix("Remission-Test-"))
    }

    func testMakeUITestServerListScenarioSeedsServers() async throws {
        // Сценарий serverListSample должен заполнить repository серверами из фикстуры.
        let dependencies = AppDependencies.makeUITest(
            fixture: .serverListSample,
            scenario: nil,
            environment: [:]
        )

        let servers = try await dependencies.serverConfigRepository.load()
        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers[0].name, "UI Test NAS")
    }

    func testMakeUITestTorrentListOfflineThrowsOnFetchList() async {
        // В offline-сценарии репозиторий торрентов должен возвращать сетевую ошибку.
        let dependencies = AppDependencies.makeUITest(
            fixture: nil,
            scenario: .torrentListOffline,
            environment: [:]
        )

        do {
            _ = try await dependencies.torrentRepository.fetchList()
            XCTFail("Ожидали APIError.networkUnavailable, но fetchList прошёл")
        } catch let error as APIError {
            XCTAssertEqual(error, .networkUnavailable)
        } catch {
            XCTFail("Получили неожиданный тип ошибки: \(error)")
        }
    }

    func testStorageNamespaceSeparatesReleaseAndDevelopment() {
        let release = AppStorageNamespace.release
        let development = AppStorageNamespace.development

        XCTAssertEqual(release.applicationSupportDirectoryName, "Remission")
        XCTAssertEqual(development.applicationSupportDirectoryName, "Remission-Dev")
        XCTAssertNil(release.userDefaultsSuiteName)
        XCTAssertEqual(development.userDefaultsSuiteName, "com.remission.dev")
        XCTAssertEqual(release.credentialsKeychainServiceIdentifier, "com.remission.transmission")
        XCTAssertEqual(
            development.credentialsKeychainServiceIdentifier,
            "com.remission.transmission.dev"
        )
        XCTAssertEqual(release.trustKeychainServiceIdentifier, "com.remission.transmission.trust")
        XCTAssertEqual(
            development.trustKeychainServiceIdentifier,
            "com.remission.transmission.trust.dev"
        )
    }

    func testStoragePathsUseNamespace() {
        let releaseServers = ServerConfigStoragePaths.defaultURL(namespace: .release)
        let developmentServers = ServerConfigStoragePaths.defaultURL(namespace: .development)
        let releaseSnapshots = ServerSnapshotStoragePaths.defaultDirectory(namespace: .release)
        let developmentSnapshots = ServerSnapshotStoragePaths.defaultDirectory(
            namespace: .development)

        XCTAssertTrue(releaseServers.path.contains("Remission/servers.json"))
        XCTAssertTrue(developmentServers.path.contains("Remission-Dev/servers.json"))
        XCTAssertTrue(releaseSnapshots.path.contains("Remission/Snapshots"))
        XCTAssertTrue(developmentSnapshots.path.contains("Remission-Dev/Snapshots"))
    }

    func testEnvironmentOverrideCanForceReleaseNamespace() {
        let namespace = AppStorageNamespace.live(environment: [
            "REMISSION_STORAGE_NAMESPACE": "release"
        ])

        XCTAssertEqual(namespace, .release)
    }

    func testDebugBuildDefaultsToDevelopmentEvenWithReleaseBundleID() {
        let namespace = AppStorageNamespace.live(
            environment: [:],
            bundleIdentifier: "cryptolin.Remission"
        )

        #if DEBUG
            XCTAssertEqual(namespace, .development)
        #else
            XCTAssertEqual(namespace, .release)
        #endif
    }

    func testLiveDetectsUnitTesting() {
        let namespace = AppStorageNamespace.live(environment: [
            "XCTestConfigurationFilePath": "/path/to/config"
        ])

        guard case .unitTesting = namespace else {
            XCTFail("Ожидали .unitTesting, получили \(namespace)")
            return
        }
    }
}
