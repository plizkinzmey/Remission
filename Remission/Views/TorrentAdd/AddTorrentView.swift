import ComposableArchitecture
import SwiftUI

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        let destinationBinding = Binding<String>(
            get: { store.destinationPath },
            set: { store.send(.destinationPathChanged($0)) }
        )
        let startPausedBinding = Binding<Bool>(
            get: { store.startPaused },
            set: { store.send(.startPausedChanged($0)) }
        )
        let newTagBinding = Binding<String>(
            get: { store.newTag },
            set: { store.send(.newTagChanged($0)) }
        )

        Form {
            Section("Источник") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Источник", systemImage: "tray.and.arrow.down.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.pendingInput.sourceDescription)
                        .font(.body)
                        .bold()
                    Text(store.pendingInput.displayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Каталог загрузки") {
                TextField("Например, /downloads", text: destinationBinding)
            }

            Section("Параметры") {
                Toggle("Запустить в паузе", isOn: startPausedBinding)
            }

            Section("Теги") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Добавить тег", text: newTagBinding)
                        Button {
                            store.send(.addTagTapped)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if store.tags.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.tags, id: \.self) { tag in
                                HStack(spacing: 12) {
                                    Text(tag)
                                        .font(.subheadline)
                                    Button {
                                        store.send(.removeTag(tag))
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        Text("Теги не заданы")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    store.send(.submitButtonTapped)
                } label: {
                    if store.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Добавить")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Отмена") {
                    store.send(.closeButtonTapped)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Добавление торрента")
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    NavigationStack {
        AddTorrentView(
            store: Store(
                initialState: AddTorrentReducer.State(
                    pendingInput: PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:demo")!,
                            rawValue: "magnet:?xt=urn:btih:demo"
                        ),
                        sourceDescription: "Буфер обмена"
                    ),
                    connectionEnvironment: .preview(server: .previewLocalHTTP),
                    destinationPath: "/downloads",
                    startPaused: true,
                    tags: ["linux", "ubuntu"]
                )
            ) {
                AddTorrentReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
    }
}

/// Простой layout для вывода тегов в несколько строк.
