import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Сервис проверки доступности сервера Transmission перед его сохранением.
struct TransmissionConnectionTester: Sendable {
    var test: @Sendable (_ server: ServerConfig, _ password: String?) async throws -> Void
}

extension TransmissionConnectionTester {
    static let placeholder: TransmissionConnectionTester = TransmissionConnectionTester(
        test: { _, _ in }
    )
}

#if canImport(ComposableArchitecture)
    extension TransmissionConnectionTester: DependencyKey {
        static var liveValue: TransmissionConnectionTester { .live() }
        static var previewValue: TransmissionConnectionTester { .placeholder }
        static var testValue: TransmissionConnectionTester { .placeholder }
    }

    extension DependencyValues {
        var transmissionConnectionTester: TransmissionConnectionTester {
            get { self[TransmissionConnectionTester.self] }
            set { self[TransmissionConnectionTester.self] = newValue }
        }
    }
#endif

extension TransmissionConnectionTester {
    static func live(
        clock: any Clock<Duration> = ContinuousClock()
    ) -> TransmissionConnectionTester {
        TransmissionConnectionTester { server, password in
            let logger = NoOpTransmissionLogger.shared
            let config = server.makeTransmissionClientConfig(
                password: password,
                network: .default,
                logger: logger
            )
            let client = TransmissionClient(config: config, clock: clock)
            _ = try await client.performHandshake()
        }
    }
}
