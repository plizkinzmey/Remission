import ComposableArchitecture
import Dependencies
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ServerListView: View {
    @Bindable var store: StoreOf<ServerListReducer>

    var body: some View {
        Group {
            if store.servers.isEmpty {
                emptyState
            } else {
                VStack(alignment: .center, spacing: 12) {
                    Text(L10n.tr("Servers"))
                        .font(.title3.bold())
                    Text(
                        L10n.tr(
                            "Manage connections, security and actions for each Transmission server."
                        )
                    )
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
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation)
        )
        .sheet(
            store: store.scope(state: \.$onboarding, action: \.onboarding)
        ) { onboardingStore in
            OnboardingView(store: onboardingStore)
                .appRootChrome()
        }
        .sheet(
            store: store.scope(state: \.$editor, action: \.editor)
        ) { editorStore in
            ServerEditorView(store: editorStore)
                .appRootChrome()
        }
        #if os(iOS)
            .background(AppBackgroundView())
        #endif
    }
}
