import ComposableArchitecture
import SwiftUI

struct DiagnosticsLogListView: View {
    let store: StoreOf<DiagnosticsReducer>

    var body: some View {
        VStack(spacing: 8) {
            if store.pendingCount > 0 {
                pendingBanner
            }

            ScrollViewReader { proxy in
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
                #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                #endif
                .onChange(of: store.scrollToLatestRequest) { _, _ in
                    guard let first = store.visibleEntries.first else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
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
}
