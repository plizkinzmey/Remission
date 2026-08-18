import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>
    @Environment(\.colorScheme) var themeColorScheme

    var body: some View {
        #if os(macOS)
            container
                .toolbar {
                    if store.connectionEnvironment != nil {
                        ToolbarItem(placement: .principal) {
                            macOSToolbarControls
                        }
                    }
                }
                .confirmationDialog(
                    $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
                )
                .alert(
                    $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
                )
        #else
            ZStack {
                if shouldShowSearchBar {
                    container
                        .searchable(
                            text: .init(
                                get: { store.searchQuery },
                                set: { store.send(.searchQueryChanged($0)) }
                            ),
                            placement: .automatic,
                            prompt: Text(L10n.tr("torrentList.search.prompt"))
                        ) {
                            ForEach(store.searchSuggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .searchCompletion(suggestion)
                            }
                        }
                } else {
                    container
                }

                if store.visibleItems.isEmpty && store.phase == .loaded {
                    TorrentListEmptyStateView()
                        .allowsHitTesting(false)
                }
            }
            .refreshable {
                store.send(.refreshRequested)
                // Ждем завершения обновления (сброса флага), игнорируя долгоживущие эффекты (поллинг)
                while store.isRefreshing {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            .background(AppBackgroundView())
            .alert(
                $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
            )
        #endif
    }
}

#if os(iOS)
    struct BlurView: UIViewRepresentable {
        let style: UIBlurEffect.Style

        func makeUIView(context: Context) -> UIVisualEffectView {
            UIVisualEffectView(effect: UIBlurEffect(style: style))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
#endif

#if DEBUG
    #Preview("Loaded list") {
        TorrentListView(store: .preview(state: .previewLoaded()))
    }
#endif
