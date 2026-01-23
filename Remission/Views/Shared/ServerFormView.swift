import ComposableArchitecture
import SwiftUI

struct ServerFormView: View {
    @Bindable var store: StoreOf<ServerFormReducer>

    var body: some View {
        NavigationStack {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(store.mode.title)
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar(contentPadding: 6) {
                        macOSFooterContent
                    }
                }
                .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
            #else
                windowContent
                    .navigationTitle(store.mode.title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("common.cancel")) {
                                store.send(.delegate(.cancelled))
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.tr("common.save")) {
                                store.send(.saveButtonTapped)
                            }
                            .disabled(store.isSaveButtonDisabled)
                        }
                    }
            #endif
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(
            store: store.scope(
                state: \.serverConfig.$trustPrompt, action: \.serverConfig.trustPrompt)
        ) { promptStore in
            TransmissionTrustPromptView(store: promptStore)
        }
    }

    private var windowContent: some View {
        VStack {
            ScrollView {
                ServerConfigurationView(
                    store: store.scope(state: \.serverConfig, action: \.serverConfig),
                    isSubmitting: store.isSaving,
                    submissionLabel: store.mode.isEdit 
                        ? L10n.tr("serverEditor.saving") 
                        : L10n.tr("onboarding.status.connecting")
                )
            }
            #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                .appDismissKeyboardOnTap()
            #endif
        }
        .padding(12)
        .appCardSurface(cornerRadius: AppTheme.Radius.modal)
        .padding(.horizontal, 12)
    }

    #if os(macOS)
    @ViewBuilder
    private var macOSFooterContent: some View {
        Button(store.serverConfig.checkConnectionButtonTitle) {
            if OnboardingViewEnvironment.isOnboardingUITest {
                store.send(.serverConfig(.uiTestBypassConnection))
            } else {
                store.send(.serverConfig(.checkConnectionButtonTapped))
            }
        }
        .disabled(
            store.serverConfig.connectionStatus == .testing
                || store.serverConfig.form.isFormValid == false
        )
        .buttonStyle(AppFooterButtonStyle(variant: store.serverConfig.checkConnectionButtonVariant))
        
        Spacer(minLength: 0)
        
        Button(L10n.tr("common.cancel")) {
            store.send(.delegate(.cancelled))
        }
        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
        
        Button(L10n.tr("common.save")) {
            store.send(.saveButtonTapped)
        }
        .disabled(store.isSaveButtonDisabled)
        .buttonStyle(AppPrimaryButtonStyle())
    }
    #endif
}

private enum OnboardingViewEnvironment {
    static let isOnboardingUITest: Bool = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-scenario=onboarding-flow")
}
