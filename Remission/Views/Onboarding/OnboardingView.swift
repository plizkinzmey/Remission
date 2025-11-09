import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingReducer>

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                securitySection
                credentialsSection
                statusSection

                if let validationError = store.validationError {
                    Section {
                        Text(validationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(store.isSubmitting)
            .overlay(submissionOverlay)
            .navigationTitle("Новый сервер")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        store.send(.cancelButtonTapped)
                    }
                    .accessibilityIdentifier("onboarding_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить сервер") {
                        store.send(.connectButtonTapped)
                    }
                    .disabled(store.isSaveButtonDisabled)
                    .accessibilityIdentifier("onboarding_submit_button")
                }
            }
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .sheet(
            store: store.scope(state: \.$trustPrompt, action: \.trustPrompt)
        ) { promptStore in
            TransmissionTrustPromptView(store: promptStore)
        }
    }

    private var connectionSection: some View {
        Section("Подключение") {
            TextField("Имя сервера", text: $store.name)
            #if os(iOS)
                TextField("Host", text: $store.host)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Host", text: $store.host)
                    .textContentType(.URL)
            #endif
            #if os(iOS)
                TextField("Порт", text: $store.port)
                    .keyboardType(.numberPad)
            #else
                TextField("Порт", text: $store.port)
            #endif
            #if os(iOS)
                TextField("Путь", text: $store.path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Путь", text: $store.path)
            #endif
        }
    }

    private var securitySection: some View {
        Section("Безопасность") {
            Picker("Протокол", selection: $store.transport) {
                ForEach(OnboardingReducer.Transport.allCases, id: \.self) { transport in
                    Text(transport.title).tag(transport)
                }
            }
            .pickerStyle(.segmented)

            if store.transport == .https {
                Toggle(
                    "Разрешить недоверенные сертификаты", isOn: $store.allowUntrustedCertificates)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HTTP небезопасен")
                        .font(.subheadline)
                        .bold()
                    Text("Данные (включая логин и пароль) передаются без шифрования.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle(
                        "Не предупреждать для этого сервера",
                        isOn: $store.suppressInsecureWarning
                    )
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private var credentialsSection: some View {
        Section("Учетные данные") {
            #if os(iOS)
                TextField("Имя пользователя", text: $store.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            #else
                TextField("Имя пользователя", text: $store.username)
            #endif
            SecureField("Пароль", text: $store.password)
        }
    }

    private var statusSection: some View {
        Section("Статус подключения") {
            Button {
                store.send(.checkConnectionButtonTapped)
            } label: {
                Label("Проверить подключение", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.connectionStatus == .testing || store.isFormValid == false)
            .accessibilityIdentifier("onboarding_connection_check_button")

            switch store.connectionStatus {
            case .idle:
                Text("Проверка не выполнялась")
                    .foregroundStyle(.secondary)

            case .testing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Проверяем соединение…")
                }
                .accessibilityIdentifier("onboarding_connection_testing")

            case .success(let handshake):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Соединение подтверждено", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(
                        handshake.serverVersionDescription
                            ?? "RPC \(handshake.rpcVersion)"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("onboarding_connection_success")

            case .failed(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("onboarding_connection_error")
            }
        }
    }

    @ViewBuilder
    private var submissionOverlay: some View {
        if store.isSubmitting {
            ZStack {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView("Подключение…")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
    }
}

#Preview {
    OnboardingView(
        store: Store(
            initialState: OnboardingReducer.State()
        ) {
            OnboardingReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
        }
    )
}
