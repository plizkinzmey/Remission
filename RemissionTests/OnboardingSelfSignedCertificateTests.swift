import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length

@MainActor
struct OnboardingSelfSignedCertificateTests {
    @Test("Self-signed сертификат можно отклонить при запросе доверия")
    func rejectsSelfSignedCertificate() async throws {
        let trustCenter = TransmissionTrustPromptCenter()
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000444")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_300_000)

        let challenge = TransmissionTrustChallenge(
            identity: .init(host: "nas.local", port: 9091, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "NAS Root",
                organization: "Home",
                validFrom: Date(),
                validUntil: Date().addingTimeInterval(86_400),
                sha256Fingerprint: Data(repeating: 0xCD, count: 32)
            )
        )

        var initialState = OnboardingReducer.State()
        initialState.host = "nas.local"
        initialState.port = "9091"

        let expectedServer = ServerConfig(
            id: fixedUUID,
            name: "nas.local",
            connection: .init(host: "nas.local", port: 9091, path: "/transmission/rpc"),
            security: .https(allowUntrustedCertificates: false),
            authentication: nil,
            createdAt: fixedDate
        )
        let expectedContext = OnboardingReducer.SubmissionContext(
            server: expectedServer,
            password: nil,
            insecureFingerprint: nil
        )

        let store = TestStore(initialState: initialState) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.transmissionTrustPromptCenter = trustCenter
            dependencies.uuidGenerator = UUIDGeneratorDependency { fixedUUID }
            dependencies.dateProvider = DateProviderDependency { fixedDate }
            dependencies.serverConnectionProbe = ServerConnectionProbe(
                run: { _, handler in
                    guard let handler else {
                        return .init(
                            handshake: TransmissionHandshakeResult(
                                sessionID: "test",
                                rpcVersion: 20,
                                minimumSupportedRpcVersion: 14,
                                serverVersionDescription: "Transmission 4.0",
                                isCompatible: true
                            )
                        )
                    }

                    let decision = await handler(challenge)
                    switch decision {
                    case .trustPermanently:
                        return .init(
                            handshake: TransmissionHandshakeResult(
                                sessionID: "test",
                                rpcVersion: 20,
                                minimumSupportedRpcVersion: 14,
                                serverVersionDescription: "Transmission 4.0",
                                isCompatible: true
                            )
                        )
                    case .deny:
                        throw ServerConnectionProbe.ProbeError.handshakeFailed(
                            "Пользователь отказался доверять сертификату"
                        )
                    }
                }
            )
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
        }

        let expectedPrompt = TransmissionTrustPrompt(
            challenge: challenge,
            resolver: { _ in }
        )

        await store.receive(.trustPromptReceived(expectedPrompt), timeout: .seconds(1)) {
            $0.trustPrompt = OnboardingReducer.TrustPromptReducer.State(prompt: expectedPrompt)
        }

        await store.send(.trustPrompt(.presented(.cancelled))) {
            $0.trustPrompt = nil
        }

        await store.receive(
            .connectionTestFinished(
                .failure("Пользователь отказался доверять сертификату")
            )
        ) {
            $0.connectionStatus = .failed("Пользователь отказался доверять сертификату")
            $0.pendingSubmission = nil
            $0.verifiedSubmission = nil
        }

        await store.finish()
    }

    @Test("Self-signed сертификат можно подтвердить и завершить проверку")
    func acceptsSelfSignedCertificate() async throws {
        let trustCenter = TransmissionTrustPromptCenter()
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000445")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_400_000)
        let handshake = TransmissionHandshakeResult(
            sessionID: "trusted-session",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0",
            isCompatible: true
        )

        let challenge = TransmissionTrustChallenge(
            identity: .init(host: "nas.local", port: 9091, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "NAS Root",
                organization: "Home",
                validFrom: Date(),
                validUntil: Date().addingTimeInterval(86_400),
                sha256Fingerprint: Data(repeating: 0xAB, count: 32)
            )
        )

        var initialState = OnboardingReducer.State()
        initialState.host = "nas.local"
        initialState.port = "9091"

        let expectedServer = ServerConfig(
            id: fixedUUID,
            name: "nas.local",
            connection: .init(host: "nas.local", port: 9091, path: "/transmission/rpc"),
            security: .https(allowUntrustedCertificates: false),
            authentication: nil,
            createdAt: fixedDate
        )
        let expectedContext = OnboardingReducer.SubmissionContext(
            server: expectedServer,
            password: nil,
            insecureFingerprint: nil
        )

        let store = TestStore(initialState: initialState) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.transmissionTrustPromptCenter = trustCenter
            dependencies.uuidGenerator = UUIDGeneratorDependency { fixedUUID }
            dependencies.dateProvider = DateProviderDependency { fixedDate }
            dependencies.serverConnectionProbe = ServerConnectionProbe(
                run: { _, handler in
                    guard let handler else {
                        return .init(handshake: handshake)
                    }
                    let decision = await handler(challenge)
                    switch decision {
                    case .trustPermanently:
                        return .init(handshake: handshake)
                    case .deny:
                        throw ServerConnectionProbe.ProbeError.handshakeFailed(
                            "Отклонено пользователем"
                        )
                    }
                }
            )
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
        }

        let expectedPrompt = TransmissionTrustPrompt(
            challenge: challenge,
            resolver: { _ in }
        )

        await store.receive(.trustPromptReceived(expectedPrompt), timeout: .seconds(1)) {
            $0.trustPrompt = OnboardingReducer.TrustPromptReducer.State(prompt: expectedPrompt)
        }
        let firstPromptState = try #require(store.state.trustPrompt)
        #expect(firstPromptState.prompt.challenge == expectedPrompt.challenge)

        await store.send(.trustPrompt(.presented(.trustConfirmed))) {
            $0.trustPrompt = nil
        }

        await store.receive(.connectionTestFinished(.success(handshake))) {
            $0.connectionStatus = .success(handshake)
            $0.pendingSubmission = nil
            $0.verifiedSubmission = expectedContext
        }

        // Завершаем долгоживущие эффекты (listener trust prompts)
        await store.finish()
    }

    @Test("Self-signed сертификат принимается с первой попытки")
    func acceptSelfSignedCertificateDirectly() async throws {
        let trustCenter = TransmissionTrustPromptCenter()
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000445")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_400_000)
        let handshake = TransmissionHandshakeResult(
            sessionID: "trusted-session",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0",
            isCompatible: true
        )

        let challenge = TransmissionTrustChallenge(
            identity: .init(host: "nas.local", port: 9091, isSecure: true),
            reason: .untrustedCertificate,
            certificate: .init(
                commonName: "NAS Root",
                organization: "Home",
                validFrom: Date(),
                validUntil: Date().addingTimeInterval(86_400),
                sha256Fingerprint: Data(repeating: 0xEF, count: 32)
            )
        )

        var initialState = OnboardingReducer.State()
        initialState.host = "nas.local"
        initialState.port = "9091"

        let expectedServer = ServerConfig(
            id: fixedUUID,
            name: "nas.local",
            connection: .init(host: "nas.local", port: 9091, path: "/transmission/rpc"),
            security: .https(allowUntrustedCertificates: false),
            authentication: nil,
            createdAt: fixedDate
        )
        let expectedContext = OnboardingReducer.SubmissionContext(
            server: expectedServer,
            password: nil,
            insecureFingerprint: nil
        )

        let store = TestStore(initialState: initialState) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.transmissionTrustPromptCenter = trustCenter
            dependencies.uuidGenerator = UUIDGeneratorDependency { fixedUUID }
            dependencies.dateProvider = DateProviderDependency { fixedDate }
            dependencies.serverConnectionProbe = ServerConnectionProbe(
                run: { _, handler in
                    guard let handler else {
                        return .init(handshake: handshake)
                    }

                    let decision = await handler(challenge)
                    switch decision {
                    case .trustPermanently:
                        return .init(handshake: handshake)
                    case .deny:
                        throw ServerConnectionProbe.ProbeError.handshakeFailed(
                            "Пользователь отказался доверять сертификату"
                        )
                    }
                }
            )
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
        }

        let expectedPrompt = TransmissionTrustPrompt(
            challenge: challenge,
            resolver: { _ in }
        )

        await store.receive(.trustPromptReceived(expectedPrompt), timeout: .seconds(1)) {
            $0.trustPrompt = OnboardingReducer.TrustPromptReducer.State(prompt: expectedPrompt)
        }

        await store.send(.trustPrompt(.presented(.trustConfirmed))) {
            $0.trustPrompt = nil
        }

        await store.receive(.connectionTestFinished(.success(handshake))) {
            $0.connectionStatus = .success(handshake)
            $0.pendingSubmission = nil
            $0.verifiedSubmission = expectedContext
        }

        await store.finish()
    }
}

// swiftlint:enable function_body_length
