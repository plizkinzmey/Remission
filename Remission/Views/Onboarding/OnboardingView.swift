import ComposableArchitecture
import Foundation
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingReducer>

    var body: some View {
        NavigationStack {
            Form {
                ServerConnectionFormFields(form: $store.form)
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

    private var statusSection: some View {
        Section("Статус подключения") {
            Button {
                if OnboardingViewEnvironment.isOnboardingUITest {
                    store.send(.uiTestBypassConnection)
                } else {
                    store.send(.checkConnectionButtonTapped)
                }
            } label: {
                Label("Проверить подключение", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.connectionStatus == .testing || store.form.isFormValid == false)
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

private enum OnboardingViewEnvironment {
    static let isOnboardingUITest: Bool = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-scenario=onboarding-flow")
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
