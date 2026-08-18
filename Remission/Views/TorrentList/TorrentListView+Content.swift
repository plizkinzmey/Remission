import ComposableArchitecture
import SwiftUI

extension TorrentListView {
    @ViewBuilder
    var container: some View {
        #if os(macOS)
            AppFooterLayout {
                VStack(alignment: .leading, spacing: 12) {
                    TorrentListHeaderView(title: L10n.tr("torrentList.section.title"))

                    if store.isRefreshing && store.isAwaitingConnection == false {
                        refreshIndicator
                            .padding(.vertical, 2)
                    }

                    TorrentListControlsView(store: store)

                    macOSScrollableContent
                        .frame(maxWidth: .infinity, alignment: .top)

                    if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                        Text(L10n.tr("torrentList.autorefresh.disabled"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            } footer: {
                footerBar
            }
        #else
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Group {
                        content
                    }
                    .redacted(reason: store.isRefreshing ? .placeholder : [])
                    .disabled(store.isRefreshing)

                    if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                        Text(L10n.tr("torrentList.autorefresh.disabled"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .top) {
                TorrentListHeaderiOSView(store: store)
                    .padding(.horizontal, 8)
                    .background(
                        BlurView(style: .regular)
                            .ignoresSafeArea(edges: .top)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0.98),
                                        .init(color: .black.opacity(0), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .ignoresSafeArea(edges: .top)
                            )
                    )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        #endif
    }

    #if os(macOS)
        @ViewBuilder
        var macOSScrollableContent: some View {
            if store.connectionEnvironment == nil && store.isAwaitingConnection == false,
                store.items.isEmpty,
                case .idle = store.phase
            {
                EmptyView()
            } else {
                switch store.phase {
                case .idle:
                    if store.isAwaitingConnection {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    TorrentRowSkeletonView(index: index)
                                        .padding(.vertical, 10)
                                        .appCardSurface(cornerRadius: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        EmptyView()
                    }

                case .loading:
                    if store.isRefreshing == false {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    TorrentRowSkeletonView(index: index)
                                        .padding(.vertical, 10)
                                        .appCardSurface(cornerRadius: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                case .loaded, .offline:
                    if store.visibleItems.isEmpty {
                        TorrentListEmptyStateView()
                    } else {
                        ScrollView {
                            torrentRowsMacOS
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                case .error:
                    EmptyView()
                }
            }
        }
    #endif

    @ViewBuilder
    var content: some View {
        if store.connectionEnvironment == nil && store.isAwaitingConnection == false,
            store.items.isEmpty,
            case .idle = store.phase
        {
            EmptyView()
        } else {
            switch store.phase {
            case .idle:
                if store.isAwaitingConnection {
                    loadingView
                } else {
                    EmptyView()
                }

            case .loading:
                if store.isRefreshing == false {
                    loadingView
                }

            case .loaded, .offline:
                if store.visibleItems.isEmpty {
                    Color.clear
                } else {
                    #if os(macOS)
                        torrentRowsMacOS
                    #else
                        torrentRows
                    #endif
                }
            case .error:
                EmptyView()
            }
        }
    }

    var loadingView: some View {
        ForEach(0..<6, id: \.self) { index in
            TorrentRowSkeletonView(index: index)
                .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
        .accessibilityIdentifier("torrent_list_loading")
    }

    var footerBar: some View {
        AppFooterInfoBar(
            leftText: storageSummaryText,
            centerText: AppVersion.footerText,
            rightText: transmissionVersionText
        )
        .accessibilityIdentifier("torrent_list_footer")
    }

    var storageSummaryText: String? {
        guard let summary = store.storageSummary else { return nil }
        let total = StorageFormatters.bytes(summary.totalBytes)
        let free = StorageFormatters.bytes(summary.freeBytes)
        return String(format: L10n.tr("storage.summary.short"), total, free)
    }

    var transmissionVersionText: String? {
        guard let handshake = store.handshake else { return nil }
        let description = handshake.serverVersionDescription?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let versionText: String
        if let description, description.isEmpty == false {
            versionText = description
        } else {
            versionText = String(
                format: L10n.tr("serverDetail.status.rpcVersion"),
                Int64(handshake.rpcVersion)
            )
        }
        return "\(L10n.tr("serverList.transmissionVersionLabel")) \(versionText)"
    }

    var torrentRows: some View {
        ForEach(store.visibleItems, id: \.id) { item in
            torrentRow(item)
        }
        .id(store.itemsRevision)
    }
}
