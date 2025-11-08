import ComposableArchitecture
import Foundation
import OSLog
import SwiftUI

/// Временная фабрика конфигурации TransmissionClient. До появления onboarding
/// возвращает тестовую локальную конфигурацию.
enum TransmissionClientBootstrap {}

@main
struct RemissionApp: App {
    @StateObject var store: StoreOf<AppReducer>
    #if os(macOS)
        @NSApplicationDelegateAdaptor(RemissionAppDelegate.self) var appDelegate
    #endif

    init() {
        let store = Store(initialState: AppBootstrap.makeInitialState()) {
            AppReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeLive()
        }

        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}

extension TransmissionClientBootstrap {
    private static let logger: Logger = Logger(
        subsystem: "app.remission.bootstrap",
        category: "TransmissionClient"
    )

    static func makeLiveDependency(
        dependencies: DependencyValues
    ) -> TransmissionClientDependency {
        logger.debug("Начало инициализации live dependency TransmissionClient.")
        guard
            let config = makeConfig(
                credentialsStore: dependencies.keychainCredentials
            )
        else {
            logger.warning("Конфигурация TransmissionClient недоступна, используем placeholder.")
            return TransmissionClientDependency.placeholder
        }

        let appClock = dependencies[keyPath: \.appClock]
        let client = TransmissionClient(config: config, clock: appClock.clock())
        #if canImport(ComposableArchitecture)
            let trustPromptCenter = dependencies.transmissionTrustPromptCenter
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())
        #endif
        let dependency = TransmissionClientDependency.live(client: client)
        logger.debug(
            "Успешно создан live dependency TransmissionClient для \(config.baseURL, privacy: .public)."
        )
        return dependency
    }

    static func makeConfig(
        credentialsStore: KeychainCredentialsDependency,
        fileURL: URL = ServerConfigStoragePaths.defaultURL()
    ) -> TransmissionClientConfig? {
        let records = ServerConfigStoragePaths.loadSnapshot(fileURL: fileURL)
        guard let record = mostRecentRecord(in: records) else {
            return nil
        }

        let mapper = TransmissionDomainMapper()
        guard let server = try? mapper.mapServerConfig(record: record, credentials: nil) else {
            logger.error("Не удалось преобразовать сохранённую конфигурацию сервера.")
            return nil
        }

        let password: String? = {
            guard let credentialsKey = server.credentialsKey else { return nil }
            do {
                return try credentialsStore.load(credentialsKey)?.password
            } catch {
                logger.error(
                    "Не удалось загрузить пароль из Keychain: \(error.localizedDescription)")
                return nil
            }
        }()

        return server.makeTransmissionClientConfig(
            password: password,
            network: .default,
            logger: DefaultTransmissionLogger()
        )
    }

    private static func mostRecentRecord(
        in records: [StoredServerConfigRecord]
    ) -> StoredServerConfigRecord? {
        records.sorted { lhs, rhs in
            (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
        .first
    }
}

#if os(macOS)
    import AppKit

    final class RemissionAppDelegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
#endif
