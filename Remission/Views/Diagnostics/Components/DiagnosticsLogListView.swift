import ComposableArchitecture
import SwiftUI

struct DiagnosticsLogListView: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        VStack(spacing: 8) {
            if store.pendingCount > 0 {
                pendingBanner
            }

            ScrollViewReader { proxy in
                #if os(macOS)
                    // macOS `List` aggressively virtualizes rows and can keep the "first row"
                    // considered visible while you scroll, which breaks our "at top" detection
                    // and causes the log to jump when new entries arrive. Use a `ScrollView`
                    // with geometry-based top detection instead.
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            let entries = store.visibleEntries
                            let firstID = entries.first?.id
                            let lastID = entries.last?.id

                            ForEach(entries) { entry in
                                let isFirst = entry.id == firstID
                                let isLast = entry.id == lastID

                                DiagnosticsLogRowView(
                                    entry: entry,
                                    onCopy: { store.send(.copyEntry(entry)) }
                                )
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.clear)
                                .background {
                                    if isFirst {
                                        GeometryReader { geo in
                                            Color.clear
                                                .preference(
                                                    key: TopRowMinYPreferenceKey.self,
                                                    value: geo.frame(in: .named(scrollSpaceName))
                                                        .minY
                                                )
                                        }
                                    }
                                }
                                .onAppear {
                                    if isLast {
                                        store.send(.loadMoreIfNeeded)
                                    }
                                }
                                .id(entry.id)

                                Divider()
                                    .opacity(0.25)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .coordinateSpace(name: scrollSpaceName)
                    .onPreferenceChange(TopRowMinYPreferenceKey.self) { minY in
                        // minY ~= 0 means the first row is aligned at the top of the scroll view.
                        // We allow a tiny negative threshold to avoid flapping due to pixel rounding.
                        store.send(.topRowVisibilityChanged(minY >= -2))
                    }
                    .onChange(of: store.scrollToLatestRequest) { _, _ in
                        guard let first = store.visibleEntries.first else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                #else
                    List {
                        let firstID = store.visibleEntries.first?.id
                        let lastID = store.visibleEntries.last?.id

                        ForEach(store.visibleEntries) { entry in
                            let isFirst = entry.id == firstID
                            let isLast = entry.id == lastID

                            DiagnosticsLogRowView(
                                entry: entry,
                                onCopy: { store.send(.copyEntry(entry)) }
                            )
                            .listRowInsets(.init(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .listRowBackground(Color.clear)
                            .onAppear {
                                if isFirst {
                                    store.send(.topRowVisibilityChanged(true))
                                }
                                if isLast {
                                    store.send(.loadMoreIfNeeded)
                                }
                            }
                            .onDisappear {
                                if isFirst {
                                    store.send(.topRowVisibilityChanged(false))
                                }
                            }
                            .id(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .transaction { $0.animation = nil }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.scrollToLatestRequest) { _, _ in
                        guard let first = store.visibleEntries.first else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                #endif
            }
        }
    }

    private var pendingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.tint)
            Text(
                String(
                    format: L10n.tr("diagnostics.newEntries.notice"),
                    Int64(store.pendingCount)
                )
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(L10n.tr("diagnostics.newEntries.jump")) {
                store.send(.jumpToLatestTapped)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appInteractivePillSurface()
        .accessibilityIdentifier("diagnostics_pending_banner")
    }

    private let scrollSpaceName: String = "diagnostics_log_scroll"
}

private struct TopRowMinYPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
