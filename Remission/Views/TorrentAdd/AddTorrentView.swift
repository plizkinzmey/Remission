import ComposableArchitecture
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("torrentAdd.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar(contentPadding: 6) {
                        Spacer(minLength: 0)
                        Button(L10n.tr("common.cancel")) {
                            store.send(.closeButtonTapped)
                        }
                        .accessibilityIdentifier("torrent_add_cancel_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
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
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
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
        Group {
            #if os(macOS)
                windowFormContent
            #else
                ScrollView {
                    windowFormContent
                }
                .scrollDismissesKeyboard(.interactively)
                .appDismissKeyboardOnTap()
            #endif
        }
    }

    private var windowFormContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            AddTorrentSourceSection(store: store)
            AddTorrentDestinationSection(store: store)
            AddTorrentOptionsSection(store: store)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 16)
        .padding(.horizontal, 12)
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
