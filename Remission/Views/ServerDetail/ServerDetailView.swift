import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        mainContent
            .overlay {
                if isConnecting {
                    VStack {
                        ServerDetailConnectionPill()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(isConnecting == false)
            .navigationTitle(store.server.name)
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(item: $store.scope(state: \.editor, action: \.editor)) { editorStore in
                ServerFormView(store: editorStore)
            }
            .sheet(
                store: store.scope(state: \.$torrentDetail, action: \.torrentDetail)
            ) { detailStore in
                NavigationStack {
                    TorrentDetailView(store: detailStore)
                        #if os(macOS)
                            .frame(
                                minWidth: 520,
                                idealWidth: 640,
                                maxWidth: 760,
                                minHeight: 520,
                                idealHeight: 560,
                                maxHeight: 600
                            )
                        #endif
                        #if !os(macOS)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(L10n.tr("serverDetail.button.close")) {
                                        detailStore.send(.delegate(.closeRequested))
                                    }
                                }
                            }
                        #endif
                }
                .appRootChrome()
            }
            .sheet(
                store: store.scope(state: \.$addTorrent, action: \.addTorrent)
            ) { addStore in
                NavigationStack {
                    AddTorrentView(store: addStore)
                }
                .appRootChrome()
            }
            .sheet(
                store: store.scope(state: \.$settings, action: \.settings)
            ) { settingsStore in
                SettingsView(store: settingsStore)
            }
            .sheet(
                store: store.scope(state: \.$diagnostics, action: \.diagnostics)
            ) { diagnosticsStore in
                DiagnosticsView(store: diagnosticsStore)
                    .appRootChrome()
            }
            .alert(
                $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
            )
            .toolbar {
                #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        macOSSettingsToolbarPill
                    }
                #else
                    ToolbarItemGroup(placement: .primaryAction) {
                        if store.torrentList.connectionEnvironment != nil {
                            Button {
                                store.send(.torrentList(.addTorrentButtonTapped))
                            } label: {
                                Label(L10n.tr("torrentList.action.add"), systemImage: "plus")
                            }
                            .accessibilityIdentifier("torrentlist_add_button")
                            .accessibilityHint(L10n.tr("torrentList.action.add"))
                        }

                        Button {
                            store.send(.settingsButtonTapped)
                        } label: {
                            Label(L10n.tr("app.action.settings"), systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("server_detail_edit_button")
                        .accessibilityHint(L10n.tr("app.action.settings"))

                        Button {
                            store.send(.diagnosticsButtonTapped)
                        } label: {
                            Label(
                                L10n.tr("diagnostics.title"),
                                systemImage: "doc.text.below.ecg"
                            )
                        }
                        .accessibilityIdentifier("server_detail_diagnostics_button")
                        .accessibilityHint(L10n.tr("diagnostics.title"))
                    }
                #endif
            }
            .overlay(alignment: .topLeading) {
                // Отдельный доступный элемент с адресом для стабильности UI-теста на macOS.
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("server_detail_address")
                    .accessibilityLabel(store.server.displayAddress)
                    .accessibilityHidden(false)
            }
    }

    private var isConnecting: Bool {
        store.connectionState.isBlockingInteractions || store.torrentList.isAwaitingConnection
    }

    private var mainContent: some View {
        Group {
            #if os(macOS)
                VStack(alignment: .leading, spacing: 16) {
                    if shouldShowConnectionSection {
                        connectionCard
                            .padding(.horizontal, AppFooterMetrics.layoutInset)
                    }
                    if shouldShowTorrentList {
                        torrentsSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.top, 12)
                .padding(.bottom, 0)
            #else
                VStack(alignment: .leading, spacing: 12) {
                    if shouldShowConnectionSection {
                        connectionCard
                    }
                    if shouldShowTorrentList {
                        torrentsSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            #endif
        }
    }

    private var shouldShowConnectionSection: Bool {
        switch store.connectionState.phase {
        case .ready, .connecting:
            return false
        default:
            return true
        }
    }

    private var shouldShowTorrentList: Bool {
        if store.connectionEnvironment != nil {
            return true
        }
        if case .connecting = store.connectionState.phase {
            return true
        }
        if store.torrentList.isAwaitingConnection {
            return true
        }
        return false
    }

    #if os(iOS) || os(visionOS)
        private var connectionCard: some View {
            connectionContent
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    #endif

    #if os(macOS)
        private var macOSSettingsToolbarPill: some View {
            HStack(spacing: 10) {
                if store.torrentList.connectionEnvironment != nil {
                    Button {
                        store.send(.torrentList(.addTorrentButtonTapped))
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("torrentlist_add_button")
                    .accessibilityLabel(L10n.tr("torrentList.action.add"))

                    Divider()
                        .frame(height: 18)
                }

                Button {
                    store.send(.diagnosticsButtonTapped)
                } label: {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server_detail_diagnostics_button")
                .accessibilityLabel(L10n.tr("diagnostics.title"))

                Divider()
                    .frame(height: 18)

                Button {
                    store.send(.settingsButtonTapped)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server_detail_edit_button")
                .accessibilityLabel(L10n.tr("app.action.settings"))

            }
            .padding(.horizontal, 12)
            .frame(height: macOSToolbarPillHeight)
            .appToolbarPillSurface()
        }

        private var macOSToolbarPillHeight: CGFloat { 34 }

        private var connectionCard: some View {
            connectionContent
        }
    #endif

    private var connectionContent: some View {
        ServerDetailConnectionCard(
            connectionState: store.connectionState,
            errorPresenter: store.errorPresenter,
            onRetry: { store.send(.retryConnectionButtonTapped) },
            onDismissError: { store.send(.errorPresenter(.bannerDismissed)) },
            onRetryError: { store.send(.errorPresenter(.retryRequested($0))) }
        )
    }

    private var torrentsSection: some View {
        TorrentListView(
            store: store.scope(state: \.torrentList, action: \.torrentList)
        )
    }
}

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
