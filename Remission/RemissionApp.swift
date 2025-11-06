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
        guard let config = makeConfig() else {
            // TODO(RTC-43): заменить на загрузку конфигурации сервера из хранилища onboarding.
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

    static func makeConfig() -> TransmissionClientConfig? {
        // TODO(RTC-43): внедрить реальный источник сохранённых серверов и
        // возвращать актуальную конфигурацию Transmission.
        guard let url = URL(string: "http://localhost:9091/transmission/rpc") else {
            return nil
        }

        return TransmissionClientConfig(
            baseURL: url,
            enableLogging: true,
            logger: DefaultTransmissionLogger()
        )
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
