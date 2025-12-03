import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>

    var body: some View {
        List {
            connectionSection
            if store.connectionEnvironment != nil {
                torrentsSection
            }
        }
        .navigationTitle(store.server.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(
            store: store.scope(state: \.$editor, action: \.editor)
        ) { editorStore in
            ServerEditorView(store: editorStore)
        }
        .sheet(
            store: store.scope(state: \.$torrentDetail, action: \.torrentDetail)
        ) { detailStore in
            NavigationStack {
                TorrentDetailView(store: detailStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("serverDetail.button.close")) {
                                detailStore.send(.delegate(.closeRequested))
                            }
                        }
                    }
            }
        }
        .sheet(
            store: store.scope(state: \.$addTorrent, action: \.addTorrent)
        ) { addStore in
            NavigationStack {
                AddTorrentView(store: addStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("serverDetail.button.close")) {
                                addStore.send(.closeButtonTapped)
                            }
                        }
                    }
            }
        }
        .fileImporter(
            isPresented: fileImporterBinding,
            allowedContentTypes: torrentContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .alert(
            $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.tr("serverDetail.button.edit")) {
                    store.send(.editButtonTapped)
                }
                .accessibilityIdentifier("server_detail_edit_button")
                .accessibilityHint(L10n.tr("serverDetail.button.edit"))
            }
        }
    }

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

    private var connectionSection: some View {
        Section(L10n.tr("serverDetail.section.connection")) {
            if let banner = store.errorPresenter.banner {
                ErrorBannerView(
                    message: banner.message,
                    onRetry: banner.retry == nil
                        ? nil
                        : { store.send(.errorPresenter(.bannerRetryTapped)) },
                    onDismiss: { store.send(.errorPresenter(.bannerDismissed)) }
                )
            }
            switch store.connectionState.phase {
            case .idle:
                Text(L10n.tr("serverDetail.status.waiting"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("server_detail_status_idle")

            case .connecting:
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.tr("serverDetail.status.connecting"))
                }
                .accessibilityIdentifier("server_detail_status_connecting")

            case .ready(let ready):
                let statusLabel = [
                    L10n.tr("serverDetail.status.connected"),
                    ready.handshake.serverVersionDescription ?? "",
                    "RPC \(ready.handshake.rpcVersion)"
                ]
                .filter { $0.isEmpty == false }
                .joined(separator: ", ")
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        L10n.tr("serverDetail.status.connected"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    if let description = ready.handshake.serverVersionDescription {
                        if description.isEmpty == false {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(
                        String(
                            format: L10n.tr("serverDetail.status.rpcVersion"),
                            Int64(ready.handshake.rpcVersion)
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("server_detail_status_connected")
                .accessibilityLabel(statusLabel)

            case .offline(let offline):
                Label(
                    L10n.tr("serverDetail.status.error"),
                    systemImage: "wifi.slash"
                )
                .foregroundStyle(.orange)
                Text(offline.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("common.retry")) {
                    store.send(.retryConnectionButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("server_detail_status_offline")

            case .failed(let failure):
                Label(L10n.tr("serverDetail.status.error"), systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text(failure.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(L10n.tr("serverDetail.action.retry")) {
                    store.send(.retryConnectionButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("server_detail_status_failed")
                .accessibilityHint(L10n.tr("serverDetail.action.retry"))
            }
        }
    }

    private var torrentsSection: some View {
        TorrentListView(
            store: store.scope(state: \.torrentList, action: \.torrentList)
        )
    }
}

private let torrentContentTypes: [UTType] = {
    if let type = UTType(filenameExtension: "torrent") {
        return [type]
    }
    return [.data]
}()

#Preview {
    ServerDetailView(
        store: Store(
            initialState: ServerDetailReducer.State(
                server: ServerConfig.previewLocalHTTP
            )
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
}
