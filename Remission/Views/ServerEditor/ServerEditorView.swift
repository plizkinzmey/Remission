import ComposableArchitecture
import SwiftUI

struct ServerEditorView: View {
    @Bindable var store: StoreOf<ServerEditorReducer>

    var body: some View {
        NavigationStack {
            Form {
                ServerConnectionFormFields(form: $store.form)

                if let validationError = store.validationError {
                    Section {
                        Text(validationError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(store.isSaving)
            .overlay(saveOverlay)
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
        }
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
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
