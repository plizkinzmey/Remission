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
            .navigationTitle("Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        store.send(.cancelButtonTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        store.send(.saveButtonTapped)
                    }
                    .disabled(store.form.isFormValid == false || store.isSaving)
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
                ProgressView("Сохраняем…")
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
