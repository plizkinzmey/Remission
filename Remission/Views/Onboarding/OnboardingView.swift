import ComposableArchitecture
import Foundation
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingReducer>

    var body: some View {
        NavigationStack {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("onboarding.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar {
                        Spacer(minLength: 0)
                        Button(L10n.tr("onboarding.action.cancel")) {
                            store.send(.cancelButtonTapped)
                        }
                        .accessibilityIdentifier("onboarding_cancel_button")
                        .buttonStyle(.bordered)
                        Button(L10n.tr("onboarding.action.saveServer")) {
                            store.send(.connectButtonTapped)
                        }
                        .disabled(store.isSaveButtonDisabled)
                        .accessibilityIdentifier("onboarding_submit_button")
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
            #else
                windowContent
                    .navigationTitle(L10n.tr("onboarding.title"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("onboarding.action.cancel")) {
                                store.send(.cancelButtonTapped)
                            }
                            .accessibilityIdentifier("onboarding_cancel_button")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.tr("onboarding.action.saveServer")) {
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
                    statusSection

                    if let validationError = store.validationError {
                        Text(validationError)
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

    private var statusSection: some View {
        AppSectionCard(L10n.tr("onboarding.section.connectionStatus")) {
            Button {
                if OnboardingViewEnvironment.isOnboardingUITest {
                    store.send(.uiTestBypassConnection)
                } else {
                    store.send(.checkConnectionButtonTapped)
                }
            } label: {
                Label(L10n.tr("onboarding.action.checkConnection"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.connectionStatus == .testing || store.form.isFormValid == false)
            .accessibilityIdentifier("onboarding_connection_check_button")

            switch store.connectionStatus {
            case .idle:
                Text(L10n.tr("onboarding.status.notTested"))
                    .foregroundStyle(.secondary)

            case .testing:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.tr("onboarding.status.testing"))
                }
                .accessibilityIdentifier("onboarding_connection_testing")

            case .success(let handshake):
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        L10n.tr("onboarding.status.success"), systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                    let rpcText = String(
                        format: L10n.tr("onboarding.status.rpcVersion"), Int64(handshake.rpcVersion)
                    )
                    Text(handshake.serverVersionDescription ?? rpcText)
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
