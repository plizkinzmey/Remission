import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

private typealias AlertAction = OnboardingReducer.AlertAction

@MainActor
struct OnboardingFeatureTests {
    // swiftlint:disable function_body_length
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
            setCompletedOnboarding: { onboardingCompleted.set($0) }
        )

        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        var initialState = OnboardingReducer.State()
        initialState.form.name = "NAS"
        initialState.form.host = "nas.local"
        initialState.form.port = "9091"
        initialState.form.username = "admin"
        initialState.form.password = "secret"

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

        let handshake = TransmissionHandshakeResult(
            sessionID: "abc",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0",
            isCompatible: true
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
            dependencies.serverConnectionProbe = ServerConnectionProbe(
                run: { _, _ in
                    .init(handshake: handshake)
                }
            )
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.validationError = nil
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
            $0.verifiedSubmission = nil
        }

        await store.receive(.connectionTestFinished(.success(handshake))) {
            $0.connectionStatus = .success(handshake)
            $0.pendingSubmission = nil
            $0.verifiedSubmission = expectedContext
        }

        await store.send(.connectButtonTapped) {
            $0.isSubmitting = true
        }

        await store.receive(.submissionFinished(.success(expectedServer))) {
            $0.isSubmitting = false
        }
        await store.receive(.delegate(.didCreate(expectedServer)))

        #expect(savedCredentials.value?.password == "secret")
        #expect(onboardingCompleted.value == true)
    }
    // swiftlint:enable function_body_length

    @Test("HTTP предупреждение показывает алерт и позволяет отменить переход")
    func httpWarningCanBeCancelled() async {
        let noopCredentialsRepository = CredentialsRepository(
            save: { _ in },
            load: { _ in nil },
            delete: { _ in }
        )

        let store = TestStore(
            initialState: {
                var state = OnboardingReducer.State()
                state.form.host = "seedbox.example.com"
                state.form.port = "80"
                return state
            }()
        ) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.credentialsRepository = noopCredentialsRepository
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { false },
                setCompletedOnboarding: { _ in }
            )
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore.inMemory()
        }

        await store.send(.binding(.set(\.form.transport, .http))) {
            $0.form.transport = .http
            $0.pendingWarningFingerprint = "seedbox.example.com:80:"
            $0.alert = AlertState<AlertAction> {
                TextState(L10n.tr("onboarding.alert.insecureConnection.title"))
            } actions: {
                ButtonState(role: .destructive, action: .insecureTransportConfirmed) {
                    TextState(L10n.tr("onboarding.alert.insecureConnection.proceed"))
                }
                ButtonState(role: .cancel, action: .insecureTransportCancelled) {
                    TextState(L10n.tr("common.cancel"))
                }
            } message: {
                TextState(
                    L10n.tr("onboarding.alert.insecureConnection.message")
                )
            }
        }

        await store.send(
            OnboardingReducer.Action.alert(
                .presented(.insecureTransportCancelled)
            )
        ) {
            $0.alert = nil
            $0.pendingWarningFingerprint = nil
            $0.form.transport = .https
        }
    }

    @Test("Неуспешная проверка соединения отображает ошибку")
    func connectionFailureShowsError() async {
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_100_000)

        var state = OnboardingReducer.State()
        state.form.host = "nas.local"
        state.form.port = "9091"

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

        let store = TestStore(initialState: state) {
            OnboardingReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.uuidGenerator = UUIDGeneratorDependency(generate: { fixedUUID })
            dependencies.dateProvider = DateProviderDependency(now: { fixedDate })
            dependencies.serverConnectionProbe = ServerConnectionProbe(
                run: { _, _ in
                    throw ServerConnectionProbe.ProbeError.handshakeFailed("timeout")
                }
            )
        }

        await store.send(.checkConnectionButtonTapped) {
            $0.pendingSubmission = expectedContext
            $0.connectionStatus = .testing
        }

        let timeoutMessage =
            "Истекло время ожидания подключения. Проверьте сеть или сервер и попробуйте снова."

        await store.receive(.connectionTestFinished(.failure(timeoutMessage))) {
            $0.connectionStatus = .failed(timeoutMessage)
            $0.pendingSubmission = nil
            $0.verifiedSubmission = nil
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
