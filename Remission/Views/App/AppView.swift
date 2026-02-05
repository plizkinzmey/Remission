import ComposableArchitecture
import Dependencies
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>
    @State var isStartupTextVisible: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        #if os(iOS)
            ZStack {
                if shouldShowStartup {
                    startupView
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            )
                        )
                        .zIndex(1)
                } else {
                    navigationContent
                }
            }
            .animation(.easeInOut(duration: 0.6), value: shouldShowStartup)
            .onOpenURL { url in
                store.send(.openTorrentFile(url))
            }
            .task {
                await store.send(.task).finish()
            }
        #else
            navigationContent
                .appRootChrome()
                .onOpenURL { url in
                    store.send(.openTorrentFile(url))
                }
                .handlesExternalEvents(
                    preferring: Set(["*"]),
                    allowing: Set(["*"])
                )
                .task { await store.send(.task).finish() }
        #endif
    }

    private var navigationContent: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            rootContent
                #if os(iOS)
                    .navigationTitle("")
                #else
                    .navigationTitle(L10n.tr("app.title"))
                #endif
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
        #if os(macOS)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        #endif
        .background(AppBackgroundView())
        .appRootChrome()
    }

    @ViewBuilder
    private var rootContent: some View {
        #if os(iOS)
            ServerListView(
                store: store.scope(state: \.serverList, action: \.serverList)
            )
        #else
            if shouldShowServerList {
                ServerListView(
                    store: store.scope(state: \.serverList, action: \.serverList),
                    showsLoadingState: store.path.isEmpty
                )
            } else {
                initialLoadingView
            }
        #endif
    }

    private var initialLoadingView: some View {
        Color.clear
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
            .appInteractivePillSurface()
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
        if store.path.isEmpty == false {
            return true
        }
        // Если серверы уже есть (например, из кэша или фикстуры)
        if store.serverList.servers.isEmpty == false {
            return true
        }
        // Если загрузка еще идет и список пуст, не показываем список (показываем сплэш или пустоту)
        if store.serverList.isLoading {
            return false
        }
        // Если загрузка завершена, показываем список (он может быть пустым, тогда сработает логика Onboarding)
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
