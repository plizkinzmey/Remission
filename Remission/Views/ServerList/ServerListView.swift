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
        Group {
            #if os(macOS)
                AppFooterLayout {
                    Group {
                        if store.servers.isEmpty {
                            if store.isLoading {
                                if showsLoadingState {
                                    loadingState
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                emptyState
                            }
                        } else {
                            VStack(alignment: .center, spacing: 12) {
                                Text(ServerListStrings.serversTitle)
                                    .font(.title3.bold())
                                Text(ServerListStrings.serversSubtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                serverList
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                } footer: {
                    AppFooterInfoBar(centerText: AppVersion.footerText)
                        .accessibilityIdentifier("server_list_footer")
                }
            #else
                Group {
                    if store.servers.isEmpty {
                        if store.isLoading {
                            if showsLoadingState {
                                loadingState
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            emptyState
                        }
                    } else {
                        VStack(alignment: .center, spacing: 12) {
                            Text(ServerListStrings.serversTitle)
                                .font(.title3.bold())
                            Text(ServerListStrings.serversSubtitle)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            serverList
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                    }
                }
            #endif
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation)
        )
        .sheet(item: $store.scope(state: \.serverForm, action: \.serverForm)) { formStore in
            ServerFormView(store: formStore)
        }
        #if os(iOS)
            .background(AppBackgroundView())
        #endif
    }
}
