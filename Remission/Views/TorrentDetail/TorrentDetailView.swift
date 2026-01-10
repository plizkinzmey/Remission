import ComposableArchitecture
import SwiftUI

struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @State var isFilesExpanded: Bool = false
    @State var isTrackersExpanded: Bool = false
    @State var isPeersExpanded: Bool = false

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 12) {
                    macOSContentCard
                    AppWindowFooterBar {
                        Spacer(minLength: 0)
                        Button(L10n.tr("serverDetail.button.close")) {
                            store.send(.delegate(.closeRequested))
                        }
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                    }
                }
                .navigationTitle(L10n.tr("torrentDetail.window.title"))
                .toolbarTitleDisplayMode(.inline)
            #else
                windowContent
                    .navigationTitle(
                        store.name.isEmpty
                            ? L10n.tr("torrentDetail.title.fallback")
                            : store.name
                    )
                    .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .task {
            await store.send(.task).finish()
        }
        .refreshable {
            await store.send(.refreshRequested).finish()
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .alert(
            $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
        )
        .overlay(alignment: .center) {
            if store.isLoading {
                loadingOverlay
            }
        }
    }

    private var windowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summarySection
                basicInformationSection

                if let banner = store.errorPresenter.banner {
                    AppSectionCard("") {
                        ErrorBannerView(
                            message: banner.message,
                            onRetry: banner.retry == nil
                                ? nil
                                : { store.send(.errorPresenter(.bannerRetryTapped)) },
                            onDismiss: { store.send(.dismissError) }
                        )
                    }
                }

                if shouldShowInitialPlaceholder {
                    AppSectionCard("") {
                        EmptyPlaceholderView(
                            systemImage: "arrow.clockwise.circle",
                            title: L10n.tr("torrentDetail.placeholder.initial.title"),
                            message: L10n.tr("torrentDetail.placeholder.initial.message")
                        )
                        .accessibilityIdentifier("torrent-detail-initial-placeholder")
                    }
                }

                if shouldShowMetadataFallback {
                    AppSectionCard("") {
                        EmptyPlaceholderView(
                            systemImage: "sparkles",
                            title: L10n.tr("torrentDetail.placeholder.metadata.title"),
                            message: L10n.tr("torrentDetail.placeholder.metadata.message")
                        )
                        .accessibilityIdentifier("torrent-detail-metadata-placeholder")
                    }
                }

                advancedSections
            }
            .padding(12)
        }
    }

    #if os(macOS)
        private var macOSContentCard: some View {
            windowContent
                .appCardSurface(cornerRadius: 16)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    #endif

    private var shouldShowInitialPlaceholder: Bool {
        store.isLoading
            && store.files.isEmpty
            && store.trackers.isEmpty
            && store.peers.isEmpty
            && store.speedHistory.samples.isEmpty
    }

    private var shouldShowMetadataFallback: Bool {
        store.isLoading == false
            && store.errorPresenter.banner == nil
            && store.hasLoadedMetadata == false
            && store.files.isEmpty
            && store.trackers.isEmpty
            && store.peers.isEmpty
    }
}
