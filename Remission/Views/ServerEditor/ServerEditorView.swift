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
                    AppWindowFooterBar {
                        Spacer(minLength: 0)
                        Button(L10n.tr("common.cancel")) {
                            store.send(.cancelButtonTapped)
                        }
                        .accessibilityIdentifier("server_editor_cancel_button")
                        .accessibilityHint(L10n.tr("common.cancel"))
                        .buttonStyle(.bordered)
                        Button(L10n.tr("serverEditor.save")) {
                            store.send(.saveButtonTapped)
                        }
                        .disabled(store.form.isFormValid == false || store.isSaving)
                        .accessibilityIdentifier("server_editor_save_button")
                        .accessibilityHint(L10n.tr("serverEditor.save"))
                        .buttonStyle(.borderedProminent)
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
                            Button(L10n.tr("serverEditor.save")) {
                                store.send(.saveButtonTapped)
                            }
                            .disabled(store.form.isFormValid == false || store.isSaving)
                            .accessibilityIdentifier("server_editor_save_button")
                            .accessibilityHint(L10n.tr("serverEditor.save"))
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
