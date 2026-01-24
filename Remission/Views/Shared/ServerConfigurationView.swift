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
        .buttonStyle(AppFooterButtonStyle(variant: store.checkConnectionButtonVariant))
    }

    @ViewBuilder
    private var submissionOverlay: some View {
        ZStack {
            Color.black.opacity(0.1)
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
