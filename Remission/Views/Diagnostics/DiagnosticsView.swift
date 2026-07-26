import ComposableArchitecture
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct DiagnosticsView: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                    VStack(spacing: 12) {
                        AppWindowHeader(L10n.tr("diagnostics.title"))
                        windowContent
                            .frame(maxHeight: .infinity, alignment: .top)

                        AppWindowFooterBar(contentPadding: 6) {
                            Spacer(minLength: 0)
                            Button(L10n.tr("diagnostics.clear")) {
                                store.send(.clearTapped)
                            }
                            .disabled(store.entries.isEmpty || store.isLoading)
                            .accessibilityIdentifier("diagnostics_clear_button")
                            .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                            Button(L10n.tr("diagnostics.close")) {
                                store.send(.delegate(.closeRequested))
                            }
                            .accessibilityIdentifier("diagnostics_close_button")
                            .buttonStyle(AppPrimaryButtonStyle())
                        }
                    }
                    // Keep the diagnostics sheet compact, but avoid forcing a fixed max height.
                    // Fixed max heights can cause the sheet to clip content (header/footer) on smaller windows.
                    .frame(minWidth: 560, idealWidth: 760, maxWidth: 980)
                    .frame(minHeight: 360, idealHeight: macOSIdealHeight, maxHeight: macOSMaxHeight)
                #else
                    windowContent
                        .navigationTitle(L10n.tr("diagnostics.title"))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.tr("diagnostics.close")) {
                                    store.send(.delegate(.closeRequested))
                                }
                                .accessibilityIdentifier("diagnostics_close_button")
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.tr("diagnostics.clear")) {
                                    store.send(.clearTapped)
                                }
                                .disabled(store.entries.isEmpty || store.isLoading)
                                .accessibilityIdentifier("diagnostics_clear_button")
                            }
                        }
                #endif
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
}

extension DiagnosticsView {
    @ViewBuilder
    private var windowContent: some View {
        VStack(spacing: 16) {
            DiagnosticsFilterSection(store: store)
                .padding(.horizontal, 12)

            VStack(spacing: 12) {
                if let limitNotice = limitNoticeText {
                    limitNoticeView(limitNotice)
                }

                logContent
            }
            .padding(12)
            .appCardSurface(cornerRadius: 16)
            .padding(.horizontal, 12)
        }
        #if os(macOS)
            // Avoid requesting infinite height on macOS sheets; it can cause the sheet to open too tall.
            .frame(maxWidth: .infinity, alignment: .top)
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #endif
        #if os(iOS)
            .appDismissKeyboardOnTap()
        #endif
    }

    private var limitNoticeText: String? {
        guard let maxEntries = store.maxEntries else { return nil }
        guard store.entries.count >= maxEntries else { return nil }
        return String(format: L10n.tr("diagnostics.limit.notice"), maxEntries)
    }

    private func limitNoticeView(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("diagnostics_limit_notice")
    }

    private var logContent: some View {
        ZStack {
            switch store.viewMode {
            case .list:
                DiagnosticsLogListView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(store.visibleEntries.isEmpty ? 0 : 1)
            case .text:
                DiagnosticsLogTextView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(store.visibleEntries.isEmpty ? 0 : 1)
            }

            if store.isLoading && store.visibleEntries.isEmpty {
                ProgressView(L10n.tr("diagnostics.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #if os(macOS)
            // Let the log area expand/shrink within the sheet height, so header/footer remain visible.
            .frame(maxWidth: .infinity)
            .frame(minHeight: 220, idealHeight: 340, maxHeight: .infinity)
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .layoutPriority(1)
    }
}

#if os(macOS)
    extension DiagnosticsView {
        private var macOSMaxHeight: CGFloat {
            let visibleHeight = NSScreen.main?.visibleFrame.height ?? 800
            // Keep a safety margin so sheets don't open beyond the visible area (menu bar / dock / window chrome).
            let capped = visibleHeight - 140
            return max(520, min(capped, 760))
        }

        private var macOSIdealHeight: CGFloat {
            min(680, macOSMaxHeight)
        }
    }
#endif

#Preview {
    DiagnosticsView(
        store: Store(
            initialState: DiagnosticsReducer.State(
                entries: IdentifiedArrayOf(
                    uniqueElements: [
                        DiagnosticsLogEntry(
                            timestamp: Date(),
                            level: .error,
                            message: "Transmission RPC error",
                            category: "transmission",
                            metadata: [
                                "method": "POST",
                                "status": "409",
                                "elapsed_ms": "124",
                                "server": "local",
                                "host": "nas.local",
                                "error": "URLError.notConnectedToInternet(-1009)",
                                "retry_attempt": "1",
                                "max_retries": "3"
                            ]
                        ),
                        DiagnosticsLogEntry(
                            timestamp: Date().addingTimeInterval(-60),
                            level: .info,
                            message: "Запрос списка торрентов",
                            category: "torrent-list",
                            metadata: [
                                "method": "torrent-get",
                                "status": "200",
                                "elapsed_ms": "42"
                            ]
                        )
                    ]
                ),
                selectedLevel: .info,
                maxEntries: 2
            )
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = .placeholder
        }
    )
}
