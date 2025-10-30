import ComposableArchitecture
import Foundation
import SwiftUI

/// Временная фабрика конфигурации TransmissionClient. До появления onboarding
/// возвращает тестовую локальную конфигурацию.
private enum TransmissionClientBootstrap {}

@main
struct RemissionApp: App {
    @StateObject var store: StoreOf<AppReducer>

    init() {
        let store = Store(initialState: AppBootstrap.makeInitialState()) {
            AppReducer()
        } withDependencies: { dependencies in
            dependencies.transmissionClient = TransmissionClientBootstrap.makeLiveDependency(
                dependencies: dependencies)
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
    fileprivate static func makeLiveDependency(
        dependencies: DependencyValues
    ) -> TransmissionClientDependency {
        guard let config = makeConfig() else {
            // TODO(RTC-43): заменить на загрузку конфигурации сервера из хранилища onboarding.
            return TransmissionClientDependency.placeholder
        }

        let transmissionClock = dependencies[keyPath: \.transmissionClock]
        let client = TransmissionClient(config: config, clock: transmissionClock.clock())
        #if canImport(ComposableArchitecture)
            let trustPromptCenter = dependencies.transmissionTrustPromptCenter
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())
        #endif
        return TransmissionClientDependency.live(client: client)
    }

    fileprivate static func makeConfig() -> TransmissionClientConfig? {
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
