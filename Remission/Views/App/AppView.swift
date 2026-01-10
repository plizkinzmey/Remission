import ComposableArchitecture
import Dependencies
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            rootContent
                .navigationTitle(L10n.tr("app.title"))
                .toolbar {
                    #if os(macOS)
                        if shouldShowAddServerToolbarButton {
                            ToolbarItem(placement: .primaryAction) { macOSToolbarPill }
                        }
                    #else
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if shouldShowAddServerToolbarButton {
                                addServerButton
                            }
                        }
                    #endif
                }
        } destination: { store in
            ServerDetailView(store: store)
        }
        .appRootChrome()
        #if os(macOS)
            .handlesExternalEvents(
                preferring: Set(["*"]),
                allowing: Set(["*"])
            )
        #endif
        .onOpenURL { url in
            store.send(.openTorrentFile(url))
        }
        .task {
            await store.send(.serverList(.task)).finish()
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if shouldShowServerList {
            ServerListView(
                store: store.scope(state: \.serverList, action: \.serverList)
            )
        } else {
            initialLoadingView
        }
    }

    private var initialLoadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addServerButton: some View {
        Button {
            store.send(.serverList(.addButtonTapped))
        } label: {
            Label(L10n.tr("app.action.addServer"), systemImage: "plus")
        }
        .accessibilityIdentifier("app_add_server_button")
        .accessibilityHint(L10n.tr("serverList.action.addServer"))
    }

    #if os(macOS)
        private var macOSToolbarPill: some View {
            HStack(spacing: 10) {
                if shouldShowAddServerToolbarButton {
                    toolbarIconButton(
                        systemImage: "plus",
                        accessibilityIdentifier: "app_add_server_button"
                    ) {
                        store.send(.serverList(.addButtonTapped))
                    }
                    .accessibilityHint(L10n.tr("serverList.action.addServer"))
                }

            }
            .padding(.horizontal, 12)
            .frame(height: macOSToolbarPillHeight)
            .appToolbarPillSurface()
        }

        private func toolbarIconButton(
            systemImage: String,
            accessibilityIdentifier: String,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityIdentifier)
        }

        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif

    private var shouldShowAddServerToolbarButton: Bool {
        store.serverList.servers.isEmpty == false
    }

    private var shouldShowServerList: Bool {
        if store.hasLoadedServersOnce == false, store.path.isEmpty {
            return false
        }
        if store.path.isEmpty == false {
            return true
        }
        if store.serverList.isLoading, store.serverList.servers.isEmpty {
            return false
        }
        return true
    }
}

#Preview("AppView Empty") {
    AppView(
        store: Store(
            initialState: AppReducer.State()
        ) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

#Preview("AppView Sample") {
    AppView(
        store: Store(initialState: sampleState()) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

#Preview("AppView Legacy Migration") {
    AppView(
        store: Store(initialState: migratedLegacyState()) {
            AppReducer()
        } withDependencies: {
            $0 = previewDependencies()
        }
    )
}

@MainActor
private func sampleState() -> AppReducer.State {
    var state: AppReducer.State = .init()
    state.serverList.servers = [
        ServerConfig.previewLocalHTTP,
        ServerConfig.previewSecureSeedbox
    ]
    return state
}

@MainActor
private func migratedLegacyState() -> AppReducer.State {
    var serverList = ServerListReducer.State()
    serverList.servers = [
        ServerConfig.previewLocalHTTP
    ]
    let legacyDetailState = ServerDetailReducer.State(server: .previewLocalHTTP)
    let legacyState = AppReducer.State(
        version: .legacy,
        serverList: serverList,
        path: StackState([legacyDetailState])
    )
    return AppBootstrap.makeInitialState(
        arguments: [],
        targetVersion: .latest,
        existingState: legacyState
    )
}

@MainActor
private func previewDependencies() -> DependencyValues {
    var dependencies = AppDependencies.makePreview()
    dependencies.credentialsRepository = .previewMock()
    dependencies.transmissionClient = .previewMock()
    return dependencies
}
