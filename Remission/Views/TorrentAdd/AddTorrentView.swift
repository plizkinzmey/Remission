import ComposableArchitecture
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 0) {
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Spacer()
                        Button(L10n.tr("common.cancel")) {
                            store.send(.closeButtonTapped)
                        }
                        .accessibilityIdentifier("torrent_add_cancel_button")
                        .buttonStyle(.bordered)
                        Button(L10n.tr("torrentAdd.action.add")) {
                            store.send(.submitButtonTapped)
                        }
                        .disabled(
                            store.isSubmitting
                                || store.pendingInput == nil
                                || store.destinationPath.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty
                        )
                        .accessibilityIdentifier("torrent_add_submit_button")
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(.bar)
                }
            #else
                windowContent
                    .navigationTitle(L10n.tr("torrentAdd.title"))
            #endif
        }
        #if os(macOS)
            .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
        #endif
        #if !os(macOS)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        store.send(.closeButtonTapped)
                    }
                    .accessibilityIdentifier("torrent_add_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("torrentAdd.action.add")) {
                        store.send(.submitButtonTapped)
                    }
                    .disabled(
                        store.isSubmitting
                            || store.pendingInput == nil
                            || store.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                    )
                    .accessibilityIdentifier("torrent_add_submit_button")
                }
            }
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fileImporter(
            isPresented: fileImporterBinding,
            allowedContentTypes: torrentContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
    }
}

extension AddTorrentView {
    private var fileImporterBinding: Binding<Bool> {
        Binding(
            get: { store.isFileImporterPresented },
            set: { store.send(.fileImporterPresented($0)) }
        )
    }

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            store.send(.fileImportResult(.success(url)))
        case .failure(let error):
            store.send(.fileImportResult(.failure(error.localizedDescription)))
        }
    }

    fileprivate var windowContent: some View {
        Form {
            AddTorrentSourceSection(store: store)
            AddTorrentDestinationSection(store: store)
            AddTorrentOptionsSection(store: store)
        }
        #if os(macOS)
            .formStyle(.grouped)
        #endif
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            .appDismissKeyboardOnTap()
        #endif
    }
}

#Preview {
    NavigationStack {
        AddTorrentView(
            store: Store(
                initialState: {
                    var state = AddTorrentReducer.State(
                        connectionEnvironment: .preview(server: .previewLocalHTTP)
                    )
                    state.destinationPath = "/downloads"
                    state.startPaused = true
                    state.category = .series
                    state.source = .magnetLink
                    state.magnetText = "magnet:?xt=urn:btih:demo"
                    state.pendingInput = PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:demo")!,
                            rawValue: "magnet:?xt=urn:btih:demo"
                        ),
                        sourceDescription: "Буфер обмена"
                    )
                    return state
                }()
            ) {
                AddTorrentReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
    }
}
