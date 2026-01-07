import ComposableArchitecture
import Foundation
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingReducer>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("onboarding.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar {
                        Button(checkConnectionButtonTitle) {
                            if OnboardingViewEnvironment.isOnboardingUITest {
                                store.send(.uiTestBypassConnection)
                            } else {
                                store.send(.checkConnectionButtonTapped)
                            }
                        }
                        .disabled(
                            store.connectionStatus == .testing || store.form.isFormValid == false
                        )
                        .accessibilityIdentifier("onboarding_connection_check_button")
                        .buttonStyle(AppFooterButtonStyle(variant: checkConnectionButtonVariant))
                        Spacer(minLength: 0)
                        Button(L10n.tr("onboarding.action.cancel")) {
                            store.send(.cancelButtonTapped)
                        }
                        .accessibilityIdentifier("onboarding_cancel_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                        Button(L10n.tr("common.save")) {
                            store.send(.connectButtonTapped)
                        }
                        .disabled(store.isSaveButtonDisabled)
                        .accessibilityIdentifier("onboarding_submit_button")
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
                .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
            #else
                windowContent
                    .navigationTitle(L10n.tr("onboarding.title"))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(checkConnectionButtonTitle) {
                                if OnboardingViewEnvironment.isOnboardingUITest {
                                    store.send(.uiTestBypassConnection)
                                } else {
                                    store.send(.checkConnectionButtonTapped)
                                }
                            }
                            .disabled(
                                store.connectionStatus == .testing
                                    || store.form.isFormValid == false
                            )
                            .accessibilityIdentifier("onboarding_connection_check_button")
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("onboarding.action.cancel")) {
                                store.send(.cancelButtonTapped)
                            }
                            .accessibilityIdentifier("onboarding_cancel_button")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.tr("common.save")) {
                                store.send(.connectButtonTapped)
                            }
                            .disabled(store.isSaveButtonDisabled)
                            .accessibilityIdentifier("onboarding_submit_button")
                        }
                    }
            #endif
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

    private var windowContent: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ServerConnectionFormFields(form: $store.form)

                    if let validationError = store.validationError {
                        Text(validationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if case .failed(let message) = store.connectionStatus {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(12)
        .appCardSurface(cornerRadius: 16)
        .padding(.horizontal, 12)
        .disabled(store.isSubmitting)
        .overlay(submissionOverlay)
    }

    private var checkConnectionButtonTitle: String {
        switch store.connectionStatus {
        case .idle:
            return L10n.tr("onboarding.action.checkConnection")
        case .testing:
            return L10n.tr("onboarding.status.testing")
        case .success:
            return L10n.tr("onboarding.status.success")
        case .failed:
            return L10n.tr("onboarding.status.error")
        }
    }

    private var checkConnectionButtonVariant: AppFooterButtonStyle.Variant {
        switch store.connectionStatus {
        case .success:
            return .success
        case .failed:
            return .error
        case .idle, .testing:
            return .neutral
        }
    }

    @ViewBuilder
    private var submissionOverlay: some View {
        if store.isSubmitting {
            ZStack {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView(L10n.tr("onboarding.status.connecting"))
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
