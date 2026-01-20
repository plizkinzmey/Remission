import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            #if os(macOS)
                VStack(alignment: .leading, spacing: 16) {
                    if shouldShowConnectionSection {
                        connectionCard
                            .padding(.horizontal, AppFooterMetrics.layoutInset)
                    }
                    if store.connectionEnvironment != nil {
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
                    if store.connectionEnvironment != nil {
                        torrentsSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            #endif
        }
        .overlay {
            if case .connecting = store.connectionState.phase {
                ZStack {
                    connectionPill
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
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
                .appRootChrome()
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
                        Label(L10n.tr("diagnostics.title"), systemImage: "doc.text.below.ecg")
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

    private var shouldShowConnectionSection: Bool {
        switch store.connectionState.phase {
        case .ready, .connecting:
            return false
        default:
            return true
        }
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

    @ViewBuilder
    private var connectionContent: some View {
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
            HStack {
                Spacer(minLength: 0)
                connectionPill
                Spacer(minLength: 0)
            }

        case .ready:
            EmptyView()

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

    private var connectionPill: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            Text(L10n.tr("serverDetail.status.connecting"))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .fixedSize(horizontal: true, vertical: false)
        .background(connectionPillBackground)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
        )
        .accessibilityIdentifier("server_detail_status_connecting")
    }

    private var connectionPillBackground: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Glass.tint(colorScheme)
                            .opacity(colorScheme == .dark ? 0.60 : 0.35),
                        AppTheme.Background.glowColor(colorScheme)
                            .opacity(colorScheme == .dark ? 0.35 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05))
                    .blendMode(.multiply)
            )
            .shadow(
                color: AppTheme.Shadow.card(colorScheme),
                radius: 8,
                x: 0,
                y: 4
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
