import ComposableArchitecture
import SwiftUI

struct ServerFormView: View {
    @Bindable var store: StoreOf<ServerFormReducer>

    var body: some View {
        NavigationStack {
            #if os(macOS)
                VStack(spacing: 0) {
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
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
                        .buttonStyle(.bordered)
                        .tint(checkConnectionTint)

                        Spacer(minLength: 0)

                        Button(L10n.tr("common.cancel")) {
                            store.send(.delegate(.cancelled))
                        }
                        .buttonStyle(.bordered)

                        Button(L10n.tr("common.save")) {
                            store.send(.saveButtonTapped)
                        }
                        .disabled(store.isSaveButtonDisabled)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(.bar)
                }
                .frame(width: 480, height: 500)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
    }

    private var windowContent: some View {
        ServerConfigurationView(
            store: store.scope(state: \.serverConfig, action: \.serverConfig),
            isSubmitting: store.isSaving,
            submissionLabel: store.mode.isEdit
                ? L10n.tr("serverEditor.saving")
                : L10n.tr("onboarding.status.connecting")
        )
        #if os(macOS)
            .formStyle(.grouped)
        #endif
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .appDismissKeyboardOnTap()
        #endif
    }

    #if os(macOS)
        private var checkConnectionTint: Color? {
            switch store.serverConfig.checkConnectionButtonVariant {
            case .accent: return .accentColor
            case .success: return .green
            case .error: return .red
            case .neutral: return nil
            }
        }
    #endif
}

private enum OnboardingViewEnvironment {
    static let isOnboardingUITest: Bool = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-scenario=onboarding-flow")
}

#if DEBUG
    #Preview("Server Form - Add") {
        NavigationStack {
            ServerFormView(
                store: Store(
                    initialState: ServerFormReducer.State(mode: .add)
                ) {
                    ServerFormReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }

    #Preview("Server Form - Edit") {
        NavigationStack {
            ServerFormView(
                store: Store(
                    initialState: ServerFormReducer.State(
                        mode: .edit(.previewLocalHTTP)
                    )
                ) {
                    ServerFormReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }
#endif
