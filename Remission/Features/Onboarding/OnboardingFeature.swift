import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingReducer {
    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case failed(String)
    }

    enum Transport: String, CaseIterable, Hashable, Sendable {
        case https
        case http

        var title: String {
            switch self {
            case .https: return "HTTPS"
            case .http: return "HTTP"
            }
        }
    }

    @ObservableState
    struct State: Equatable {

        var name: String = ""
        var host: String = ""
        var port: String = "9091"
        var path: String = "/transmission/rpc"
        var transport: Transport = .https
        var allowUntrustedCertificates: Bool = false
        var username: String = ""
        var password: String = ""
        var suppressInsecureWarning: Bool = false
        var validationError: String?
        var isSubmitting: Bool = false
        var pendingWarningFingerprint: String?
        var connectionStatus: ConnectionStatus = .idle
        var pendingSubmission: SubmissionContext?
        @Presents var alert: AlertState<AlertAction>?

        var trimmedHost: String {
            host.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var normalizedPath: String {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return "/transmission/rpc" }
            return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        }

        var portValue: Int? {
            guard let value = Int(port), (1...65535).contains(value) else { return nil }
            return value
        }

        var isFormValid: Bool {
            trimmedHost.isEmpty == false && portValue != nil
        }

        var isConnectButtonDisabled: Bool {
            isFormValid == false || isSubmitting || connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case connectButtonTapped
        case cancelButtonTapped
        case submissionFinished(Result<ServerConfig, SubmissionError>)
        case connectionTestFinished(ConnectionTestResult)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case insecureTransportConfirmed
        case insecureTransportCancelled
        case errorDismissed
    }

    enum ConnectionTestResult: Equatable {
        case success
        case failure(String)
    }

    enum Delegate: Equatable {
        case didCreate(ServerConfig)
        case cancelled
    }

    struct SubmissionError: Equatable, Error {
        var message: String
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.dateProvider) var dateProvider
    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository
    @Dependency(\.transmissionConnectionTester) var transmissionConnectionTester

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.validationError = nil
                if state.transport == .https {
                    state.suppressInsecureWarning = false
                }
                if state.transport == .https {
                    state.pendingWarningFingerprint = nil
                }
                return .none

            case .connectButtonTapped:
                guard state.connectionStatus != .testing else { return .none }
                guard
                    let context = prepareSubmission(
                        state: &state,
                        forceAllowInsecureTransport: false
                    )
                else {
                    return .none
                }
                return startConnectionTest(state: &state, context: context)

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case .submissionFinished(.success(let server)):
                state.isSubmitting = false
                return .send(.delegate(.didCreate(server)))

            case .submissionFinished(.failure(let error)):
                state.isSubmitting = false
                state.alert = AlertState {
                    TextState("Не удалось добавить сервер")
                } actions: {
                    ButtonState(role: .cancel, action: .errorDismissed) {
                        TextState("Понятно")
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .alert(.presented(.insecureTransportConfirmed)):
                state.alert = nil
                if let context = prepareSubmission(
                    state: &state,
                    forceAllowInsecureTransport: true
                ) {
                    state.pendingWarningFingerprint = nil
                    return startConnectionTest(state: &state, context: context)
                }
                return .none

            case .alert(.presented(.insecureTransportCancelled)):
                state.alert = nil
                state.pendingWarningFingerprint = nil
                state.transport = .https
                return .none

            case .alert(.presented(.errorDismissed)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                return .none

            case .connectionTestFinished(.success):
                state.connectionStatus = .idle
                guard let context = state.pendingSubmission else { return .none }
                state.pendingSubmission = nil
                return persistSubmission(state: &state, context: context)

            case .connectionTestFinished(.failure(let message)):
                state.connectionStatus = .failed(message)
                state.pendingSubmission = nil
                state.isSubmitting = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

extension OnboardingReducer {
    struct SubmissionContext: Equatable, Sendable {
        var server: ServerConfig
        var password: String?
        var insecureFingerprint: String?
    }
}

extension OnboardingReducer {
    fileprivate func startConnectionTest(
        state: inout State,
        context: SubmissionContext
    ) -> Effect<Action> {
        state.pendingSubmission = context
        state.connectionStatus = .testing
        return .run { [context] send in
            do {
                try await transmissionConnectionTester.test(context.server, context.password)
                await send(.connectionTestFinished(.success))
            } catch {
                await send(
                    .connectionTestFinished(.failure(describe(error)))
                )
            }
        }
    }

    fileprivate func persistSubmission(
        state: inout State,
        context: SubmissionContext
    ) -> Effect<Action> {
        guard state.isSubmitting == false else { return .none }
        state.isSubmitting = true
        return .run { [context] send in
            do {
                if let password = context.password {
                    if let credentialsKey = context.server.credentialsKey {
                        let credentials = TransmissionServerCredentials(
                            key: credentialsKey,
                            password: password
                        )
                        try await credentialsRepository.save(credentials: credentials)
                    }
                }
                onboardingProgressRepository.setCompletedOnboarding(true)
                if let fingerprint = context.insecureFingerprint {
                    onboardingProgressRepository.acknowledgeInsecureWarning(fingerprint)
                }
                await send(.submissionFinished(.success(context.server)))
            } catch {
                await send(
                    .submissionFinished(
                        .failure(SubmissionError(message: describe(error)))
                    )
                )
            }
        }
    }

    fileprivate func prepareSubmission(
        state: inout State,
        forceAllowInsecureTransport: Bool
    ) -> SubmissionContext? {
        guard state.isFormValid, let port = state.portValue else {
            state.validationError = "Заполните хост и корректный порт."
            return nil
        }

        let context = makeSubmissionContext(
            state: state,
            host: state.trimmedHost,
            port: port
        )

        if context.server.usesInsecureTransport {
            if forceAllowInsecureTransport == false {
                let fingerprint = context.insecureFingerprint ?? ""
                let isSuppressed =
                    onboardingProgressRepository
                    .isInsecureWarningAcknowledged(fingerprint)
                if state.suppressInsecureWarning {
                    onboardingProgressRepository.acknowledgeInsecureWarning(fingerprint)
                } else if isSuppressed == false {
                    state.pendingWarningFingerprint = fingerprint
                    state.alert = AlertState {
                        TextState("Небезопасное подключение")
                    } actions: {
                        ButtonState(role: .destructive, action: .insecureTransportConfirmed) {
                            TextState("Продолжить")
                        }
                        ButtonState(role: .cancel, action: .insecureTransportCancelled) {
                            TextState("Отмена")
                        }
                    } message: {
                        TextState(
                            "HTTP соединения не шифруются. Продолжайте только если доверяете сети."
                        )
                    }
                    return nil
                }
            } else if let fingerprint = context.insecureFingerprint {
                onboardingProgressRepository.acknowledgeInsecureWarning(fingerprint)
            }
        }

        state.validationError = nil
        state.pendingWarningFingerprint = nil
        return context
    }

    fileprivate func makeSubmissionContext(
        state: State,
        host: String,
        port: Int
    ) -> SubmissionContext {
        let id = uuidGenerator.generate()
        let date = dateProvider.now()
        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let connection = ServerConfig.Connection(host: host, port: port, path: state.normalizedPath)
        let security: ServerConfig.Security =
            state.transport == .https
            ? .https(allowUntrustedCertificates: state.allowUntrustedCertificates)
            : .http

        var authentication: ServerConfig.Authentication?
        if state.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            authentication = ServerConfig.Authentication(username: state.username)
        }

        let server = ServerConfig(
            id: id,
            name: name.isEmpty ? host : name,
            connection: connection,
            security: security,
            authentication: authentication,
            createdAt: date
        )

        let password = state.password.isEmpty ? nil : state.password
        let fingerprint: String? =
            server.usesInsecureTransport
            ? Self.makeFingerprint(host: host, port: port, username: state.username)
            : nil

        return SubmissionContext(
            server: server, password: password, insecureFingerprint: fingerprint)
    }

    fileprivate static func makeFingerprint(host: String, port: Int, username: String) -> String {
        "\(host.lowercased()):\(port):\(username.lowercased())"
    }

    fileprivate func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return nsError.localizedDescription.isEmpty
            ? String(describing: error)
            : nsError.localizedDescription
    }
}

extension ServerConfig {
    fileprivate var usesInsecureTransport: Bool {
        if case .http = security {
            return true
        }
        return false
    }
}
