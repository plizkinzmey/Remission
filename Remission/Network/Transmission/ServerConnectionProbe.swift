import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Обертка над `TransmissionClient`, выполняющая проверку соединения с сервером Transmission.
/// Выполняет попытку рукопожатия с экспоненциальным retry и безопасным логированием ошибок.
struct ServerConnectionProbe: Sendable {
    struct Request: Equatable, Sendable {
        var server: ServerConfig
        var password: String?
    }

    struct Result: Equatable, Sendable {
        var handshake: TransmissionHandshakeResult
    }

    enum ProbeError: Error, Equatable {
        case handshakeFailed(String)
    }

    var run:
        @Sendable (_ request: Request, _ trustHandler: TransmissionTrustDecisionHandler?)
            async throws
            -> Result
}

// MARK: - Dependency integration

#if canImport(ComposableArchitecture)
    extension ServerConnectionProbe: DependencyKey {
        static var liveValue: ServerConnectionProbe {
            @Dependency(\.appLogger) var appLogger
            return .live(appLogger: appLogger)
        }
        static let previewValue: ServerConnectionProbe = .placeholder
        static let testValue: ServerConnectionProbe = .placeholder
    }

    extension DependencyValues {
        var serverConnectionProbe: ServerConnectionProbe {
            get { self[ServerConnectionProbe.self] }
            set { self[ServerConnectionProbe.self] = newValue }
        }
    }
#endif

extension ServerConnectionProbe {
    static let placeholder: ServerConnectionProbe = ServerConnectionProbe { _, _ in
        .init(
            handshake: TransmissionHandshakeResult(
                sessionID: nil,
                rpcVersion: 0,
                minimumSupportedRpcVersion: 0,
                serverVersionDescription: nil,
                isCompatible: false
            ))
    }

    static func live(
        clock: any Clock<Duration> = ContinuousClock(),
        appLogger: AppLogger = .noop,
        maxAttempts: Int = 3,
        initialDelay: Duration = .seconds(1),
        sessionConfiguration: URLSessionConfiguration? = nil
    ) -> ServerConnectionProbe {
        ServerConnectionProbe { request, trustHandler in
            let config = request.server.makeTransmissionClientConfig(
                password: request.password,
                network: .init(
                    requestTimeout: 20,
                    maxRetries: 0,
                    retryDelay: 0.5,
                    enableLogging: false
                )
            )

            let client = TransmissionClient.live(
                config: config,
                clock: clock,
                appLogger: appLogger,
                category: "connection.probe",
                sessionConfiguration: sessionConfiguration
            )

            if let trustHandler {
                client.setTrustDecisionHandler(trustHandler)
            }

            var attempt: Int = 0
            var backoff = ExponentialBackoffCalculator(initialDelay: initialDelay)

            while true {
                do {
                    let handshake = try await client.performHandshake()
                    return Result(handshake: handshake)
                } catch {
                    attempt += 1
                    guard attempt < maxAttempts else {
                        throw ProbeError.handshakeFailed(error.localizedDescription)
                    }
                    let delay = backoff.nextDelay()
                    try await clock.sleep(for: delay)
                }
            }
        }
    }

    /// Предсказуемый мок для UI-тестов онбординга.
    /// В UI-тестах сценарий онбординга должен работать без лишних модальных окон,
    /// поэтому мок игнорирует trustHandler и просто имитирует успешное подключение.
    static func uiTestOnboardingMock() -> ServerConnectionProbe {
        ServerConnectionProbe { _, _ in
            // Имитация минимальной задержки для реалистичности (50ms вместо 100ms)
            try? await Task.sleep(nanoseconds: 50_000_000)

            return Result(
                handshake: TransmissionHandshakeResult(
                    sessionID: "uitest-session-\(UUID().uuidString)",
                    rpcVersion: 22,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission 4.0 (UI Tests)",
                    isCompatible: true
                )
            )
        }
    }
}

extension ServerConnectionProbe.ProbeError {
    var displayMessage: String {
        switch self {
        case .handshakeFailed(let message):
            return Self.localized(message)
        }
    }

    private static func localized(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return
                "Истекло время ожидания подключения. Проверьте сеть или сервер и попробуйте снова."
        }
        if lowercased.contains("cancelled") || lowercased.contains("canceled") {
            return "Проверка подключения отменена. Повторите попытку."
        }
        return message
    }
}

extension ServerConnectionProbe {
    struct ExponentialBackoffCalculator {
        private var currentDelaySeconds: Double
        private let multiplier: Double

        init(initialDelay: Duration, multiplier: Double = 2.0) {
            self.currentDelaySeconds = max(Self.seconds(from: initialDelay), 0.001)
            self.multiplier = multiplier
        }

        mutating func nextDelay() -> Duration {
            let delay = currentDelaySeconds
            currentDelaySeconds *= multiplier
            return .seconds(delay)
        }

        mutating func collectDelays(count: Int) -> [Duration] {
            guard count > 0 else { return [] }
            return (0..<count).map { _ in nextDelay() }
        }

        private static func seconds(from duration: Duration) -> Double {
            let components = duration.components
            let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
            return Double(components.seconds) + attoseconds
        }
    }
}

extension TransmissionCertificateInfo {
    fileprivate static let uiTestSelfSigned: TransmissionCertificateInfo = {
        let fingerprint: [UInt8] = [
            0xde, 0xad, 0xbe, 0xef, 0xca, 0xfe, 0xba, 0xbe,
            0x12, 0x34, 0x56, 0x78, 0x90, 0xab, 0xcd, 0xef
        ]
        return TransmissionCertificateInfo(
            commonName: "UITest NAS",
            organization: "Remission QA",
            validFrom: nil,
            validUntil: nil,
            sha256Fingerprint: Data(fingerprint)
        )
    }()
}
