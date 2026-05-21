import ComposableArchitecture
import Dependencies
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ServerListView: View {
    @Bindable var store: StoreOf<ServerListReducer>
    let showsLoadingState: Bool

    init(
        store: StoreOf<ServerListReducer>,
        showsLoadingState: Bool = true
    ) {
        self.store = store
        self.showsLoadingState = showsLoadingState
    }

    var body: some View {
        #if os(macOS)
            if store.servers.isEmpty {
                mainContent
            } else {
                mainContent
                    .sheet(item: $store.scope(state: \.serverForm, action: \.serverForm)) { formStore in
                        ServerFormView(store: formStore)
                    }
            }
        #else
            mainContent
                .sheet(item: $store.scope(state: \.serverForm, action: \.serverForm)) { formStore in
                    ServerFormView(store: formStore)
                }
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if store.servers.isEmpty {
                if store.isLoading {
                    if showsLoadingState {
                        loadingState
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    #if os(macOS)
                        if let formStore = store.scope(
                            state: \.serverForm, action: \.serverForm.presented)
                        {
                            ServerFormView(store: formStore)
                                .frame(
                                    maxWidth: .infinity, maxHeight: .infinity, alignment: .center
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            emptyState
                                .transition(.opacity)
                        }
                    #else
                        emptyState
                    #endif
                }
            } else {
                VStack(alignment: .center, spacing: 12) {
                    Text(ServerListStrings.serversTitle)
                        .font(.title3.bold())
                    Text(ServerListStrings.serversSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    serverList
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 12)
            }
        }
        .animation(.spring(duration: 0.4), value: store.servers.isEmpty)
        .animation(.spring(duration: 0.4), value: store.serverForm == nil)
        .safeAreaInset(edge: .bottom) {
            if !store.servers.isEmpty {
                HStack {
                    Spacer()
                    Text(AppVersion.footerText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(.bar)
                .accessibilityIdentifier("server_list_footer")
            }
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation)
        )
    }
}
