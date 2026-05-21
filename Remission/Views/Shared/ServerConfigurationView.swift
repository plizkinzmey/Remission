import ComposableArchitecture
import SwiftUI

/// Унифицированное представление для настройки сервера (Onboarding / Editor).
struct ServerConfigurationView: View {
    @Bindable var store: StoreOf<ServerConfigurationReducer>
    var isSubmitting: Bool = false
    var submissionLabel: String = ""

    var body: some View {
        Form {
            ServerConnectionFormFields(form: $store.form)

            if let validationError = store.validationError {
                Section {
                    errorText(validationError)
                }
            }

            if case .failed(let message) = store.connectionStatus {
                Section {
                    errorText(message)
                }
            }

            #if os(iOS)
                Section {
                    checkConnectionButton
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            #endif
        }
        .disabled(isSubmitting)
        .blur(radius: isSubmitting ? 2 : 0)
        .overlay {
            if isSubmitting {
                submissionOverlay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSubmitting)
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
        ProgressView(submissionLabel)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// Повторяем логику определения UI теста для байпаса
private enum OnboardingViewEnvironment {
    static let isOnboardingUITest: Bool = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-scenario=onboarding-flow")
}
