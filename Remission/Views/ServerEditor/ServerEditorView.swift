import ComposableArchitecture
import SwiftUI

struct ServerEditorView: View {
    @Bindable var store: StoreOf<ServerEditorReducer>

    var body: some View {
        NavigationStack {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("serverEditor.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar(contentPadding: 6) {
                        Button(checkConnectionButtonTitle) {
                            store.send(.checkConnectionButtonTapped)
                        }
                        .disabled(
                            store.connectionStatus == .testing || store.form.isFormValid == false
                        )
                        .accessibilityIdentifier("server_editor_connection_check_button")
                        .buttonStyle(AppFooterButtonStyle(variant: checkConnectionButtonVariant))
                        Spacer(minLength: 0)
                        Button(L10n.tr("common.cancel")) {
                            store.send(.cancelButtonTapped)
                        }
                        .accessibilityIdentifier("server_editor_cancel_button")
                        .accessibilityHint(L10n.tr("common.cancel"))
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                        Button(L10n.tr("common.save")) {
                            store.send(.saveButtonTapped)
                        }
                        .disabled(store.isSaveButtonDisabled)
                        .accessibilityIdentifier("server_editor_save_button")
                        .accessibilityHint(L10n.tr("common.save"))
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
                .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
            #else
                windowContent
                    .navigationTitle(L10n.tr("serverEditor.title"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("common.cancel")) {
                                store.send(.cancelButtonTapped)
                            }
                            .accessibilityIdentifier("server_editor_cancel_button")
                            .accessibilityHint(L10n.tr("common.cancel"))
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.tr("common.save")) {
                                store.send(.saveButtonTapped)
                            }
                            .disabled(store.isSaveButtonDisabled)
                            .accessibilityIdentifier("server_editor_save_button")
                            .accessibilityHint(L10n.tr("common.save"))
                        }
                    }
            #endif
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
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

                    #if os(iOS)
                        Button(checkConnectionButtonTitle) {
                            store.send(.checkConnectionButtonTapped)
                        }
                        .disabled(
                            store.connectionStatus == .testing
                                || store.form.isFormValid == false
                        )
                        .accessibilityIdentifier("server_editor_connection_check_button")
                        .buttonStyle(AppFooterButtonStyle(variant: checkConnectionButtonVariant))
                        .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                }
            }
        }
        .padding(12)
        .appCardSurface(cornerRadius: 16)
        .padding(.horizontal, 12)
        .disabled(store.isSaving)
        .overlay(saveOverlay)
    }

    @ViewBuilder
    private var saveOverlay: some View {
        if store.isSaving {
            ZStack {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView(L10n.tr("serverEditor.saving"))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
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
}

#Preview {
    ServerEditorView(
        store: Store(
            initialState: ServerEditorReducer.State(server: .previewSecureSeedbox)
        ) {
            ServerEditorReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
            $0.serverConfigRepository = .inMemory(initial: [.previewSecureSeedbox])
        }
    )
}
