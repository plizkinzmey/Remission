import ComposableArchitecture
import SwiftUI

/// Унифицированное представление для настройки сервера (Onboarding / Editor).
struct ServerConfigurationView: View {
    @Bindable var store: StoreOf<ServerConfigurationReducer>
    var isSubmitting: Bool = false
    var submissionLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ServerConnectionFormFields(form: $store.form)

            if let validationError = store.validationError {
                errorText(validationError)
            }

            if case .failed(let message) = store.connectionStatus {
                errorText(message)
            }

            #if os(iOS)
                checkConnectionButton
                    .frame(maxWidth: .infinity, alignment: .center)
            #endif
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                submissionOverlay
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var checkConnectionButton: some View {
        Button(store.checkConnectionButtonTitle) {
            // Для UI тестов онбординга используем байпас
            if OnboardingViewEnvironment.isOnboardingUITest {
                store.send(.uiTestBypassConnection)
            } else {
                store.send(.checkConnectionButtonTapped)
            }
        }
        .disabled(store.isCheckButtonDisabled || store.form.isFormValid == false)
        .buttonStyle(.bordered)
        .tint(checkConnectionTint)
    }

    private var checkConnectionTint: Color? {
        switch store.checkConnectionButtonVariant {
        case .accent: return .accentColor
        case .success: return .green
        case .error: return .red
        case .neutral: return nil
        }
    }

    @ViewBuilder
    private var submissionOverlay: some View {
        ZStack {
            Color.secondary.opacity(0.2)
                .ignoresSafeArea()
            ProgressView(submissionLabel)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .fill(.ultraThinMaterial)
                )
        }
    }
}

// Повторяем логику определения UI теста для байпаса
private enum OnboardingViewEnvironment {
    static let isOnboardingUITest: Bool = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-scenario=onboarding-flow")
}
