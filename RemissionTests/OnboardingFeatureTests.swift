import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length

private typealias AlertAction = OnboardingReducer.AlertAction

@MainActor
struct OnboardingFeatureTests {
    @Test("Успешное подключение сохраняет пароль и завершает онбординг")
    func connectSuccess() async {
        let savedCredentials = LockedValue<TransmissionServerCredentials?>(nil)
        let onboardingCompleted = LockedValue<Bool>(false)

        let credentialsRepository = CredentialsRepository(
            save: { credentials in savedCredentials.set(credentials) },
            load: { _ in nil },
            delete: { _ in }
        )

        let onboardingProgress = OnboardingProgressRepository(
            hasCompletedOnboarding: { onboardingCompleted.value },
            setCompletedOnboarding: { onboardingCompleted.set($0) },
            isInsecureWarningAcknowledged: { _ in true },
            acknowledgeInsecureWarning: { _ in }
        )

        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        var initialState = OnboardingReducer.State()
        initialState.name = "NAS"
        initialState.host = "nas.local"
        initialState.port = "9091"
        initialState.username = "admin"
        initialState.password = "secret"

        let expectedServer = ServerConfig(
            id: fixedUUID,
            name: "NAS",
            connection: .init(host: "nas.local", port: 9091, path: "/transmission/rpc"),
            security: .https(allowUntrustedCertificates: false),
            authentication: .init(username: "admin"),
            createdAt: fixedDate
        )
        let expectedContext = OnboardingReducer.SubmissionContext(
            server: expectedServer,
            password: "secret",
            insecureFingerprint: nil
        )

        let store = TestStore(
            initialState: initialState
        ) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.credentialsRepository = credentialsRepository
            dependencies.onboardingProgressRepository = onboardingProgress
            dependencies.uuidGenerator = UUIDGeneratorDependency(generate: { fixedUUID })
            dependencies.dateProvider = DateProviderDependency(now: { fixedDate })
            dependencies.transmissionConnectionTester = TransmissionConnectionTester(
                test: { _, _ in }
            )
        }

        await store.send(.connectButtonTapped) {
            $0.validationError = nil
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
        }

        await store.receive(.connectionTestFinished(.success)) {
            $0.connectionStatus = .idle
            $0.pendingSubmission = nil
            $0.isSubmitting = true
        }

        await store.receive(.submissionFinished(.success(expectedServer))) {
            $0.isSubmitting = false
        }
        await store.receive(.delegate(.didCreate(expectedServer)))

        #expect(savedCredentials.value?.password == "secret")
        #expect(onboardingCompleted.value == true)
    }

    @Test("HTTP предупреждение показывает алерт и позволяет отменить переход")
    func httpWarningCanBeCancelled() async {
        let noopCredentialsRepository = CredentialsRepository(
            save: { _ in },
            load: { _ in nil },
            delete: { _ in }
        )

        var initialState = OnboardingReducer.State()
        initialState.host = "seedbox.example.com"
        initialState.port = "80"
        initialState.transport = .http

        let store = TestStore(
            initialState: initialState
        ) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.credentialsRepository = noopCredentialsRepository
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { false },
                setCompletedOnboarding: { _ in },
                isInsecureWarningAcknowledged: { _ in false },
                acknowledgeInsecureWarning: { _ in }
            )
            dependencies.transmissionConnectionTester = TransmissionConnectionTester(
                test: { _, _ in }
            )
        }

        await store.send(OnboardingReducer.Action.connectButtonTapped) {
            $0.pendingWarningFingerprint = "seedbox.example.com:80:"
            $0.alert = AlertState<AlertAction> {
                TextState("Небезопасное подключение")
            } actions: {
                ButtonState(role: .destructive, action: .insecureTransportConfirmed) {
                    TextState("Продолжить")
                }
                ButtonState(role: .cancel, action: .insecureTransportCancelled) {
                    TextState("Отмена")
                }
            } message: {
                TextState("HTTP соединения не шифруются. Продолжайте только если доверяете сети.")
            }
        }

        await store.send(
            OnboardingReducer.Action.alert(
                .presented(.insecureTransportCancelled)
            )
        ) {
            $0.alert = nil
            $0.pendingWarningFingerprint = nil
            $0.transport = .https
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

// swiftlint:enable function_body_length
