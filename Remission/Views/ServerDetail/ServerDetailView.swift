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
            serverSection
            securitySection
            trustSection
            actionsSection
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.tr("serverDetail.button.edit")) {
                    store.send(.editButtonTapped)
                }
            }
        }
    }

    private var serverSection: some View {
        Section(L10n.tr("serverDetail.section.server")) {
            LabeledContent(L10n.tr("serverDetail.field.name"), value: store.server.name)
            LabeledContent(
                L10n.tr("serverDetail.field.address"), value: store.server.displayAddress)
            LabeledContent(L10n.tr("serverDetail.field.protocol")) {
                securityBadge
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
            switch store.connectionState.phase {
            case .idle:
                Text(L10n.tr("serverDetail.status.waiting"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .connecting:
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.tr("serverDetail.status.connecting"))
                }

            case .ready(let ready):
                Label(
                    L10n.tr("serverDetail.status.connected"), systemImage: "checkmark.circle.fill"
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
            }
        }
    }

    private var securitySection: some View {
        Section(L10n.tr("serverDetail.section.security")) {
            if store.server.isSecure {
                Label(L10n.tr("serverDetail.security.https"), systemImage: "lock.fill")
                    .foregroundStyle(.green)
                if case .https(let allowUntrusted) = store.server.security, allowUntrusted {
                    Text(L10n.tr("serverForm.security.allowUntrusted"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(
                    L10n.tr("serverDetail.security.httpWarning"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                Text(L10n.tr("serverDetail.security.httpHint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var securityBadge: some View {
        Group {
            if store.server.isSecure {
                Label(L10n.tr("serverList.badge.https"), systemImage: "lock.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.15)))
                    .foregroundStyle(.green)
            } else {
                Label(
                    L10n.tr("serverList.badge.http"), systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .foregroundStyle(.orange)
            }
        }
        .accessibilityLabel(
            store.server.isSecure
                ? L10n.tr("serverDetail.security.state.secure")
                : L10n.tr("serverDetail.security.state.insecure")
        )
    }

    private var trustSection: some View {
        Section(L10n.tr("serverDetail.section.trust")) {
            Button(role: .destructive) {
                store.send(.resetTrustButtonTapped)
            } label: {
                Label(
                    L10n.tr("serverDetail.action.resetTrust"), systemImage: "arrow.counterclockwise"
                )
            }
            Button {
                store.send(.httpWarningResetButtonTapped)
            } label: {
                Label(
                    L10n.tr("serverDetail.action.resetHttpWarnings"),
                    systemImage: "exclamationmark.shield")
            }
        }
    }

    private var actionsSection: some View {
        Section(L10n.tr("serverDetail.section.actions")) {
            Button(role: .destructive) {
                store.send(.deleteButtonTapped)
            } label: {
                Label(L10n.tr("serverDetail.action.delete"), systemImage: "trash")
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
