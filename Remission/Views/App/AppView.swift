import ComposableArchitecture
import Dependencies
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            ServerListView(
                store: store.scope(state: \.serverList, action: \.serverList)
            )
            .navigationTitle(L10n.tr("app.title"))
            .toolbar {
                #if os(macOS)
                    if shouldShowAddServerToolbarButton {
                        ToolbarItem(placement: .primaryAction) { addServerButton }
                    }
                    if shouldShowSettingsToolbarButton {
                        ToolbarItem(placement: .primaryAction) { settingsButton }
                    }
                #else
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if shouldShowSettingsToolbarButton {
                            settingsButton
                        }
                        if shouldShowAddServerToolbarButton {
                            addServerButton
                        }
                    }
                #endif
            }
        } destination: { store in
            ServerDetailView(store: store)
        }
        .sheet(
            store: store.scope(state: \.$settings, action: \.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
        }
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

    private var settingsButton: some View {
        Button {
            store.send(.settingsButtonTapped)
        } label: {
            Label(L10n.tr("app.action.settings"), systemImage: "gearshape")
        }
        .accessibilityIdentifier("app_settings_button")
    }

    private var shouldShowAddServerToolbarButton: Bool {
        store.serverList.servers.isEmpty == false
    }

    private var shouldShowSettingsToolbarButton: Bool {
        store.serverList.servers.isEmpty == false
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
