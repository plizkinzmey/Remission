import ComposableArchitecture
import SwiftUI

struct DiagnosticsView: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                    VStack(spacing: 12) {
                        AppWindowHeader(L10n.tr("diagnostics.title"))
                        windowContent
                    }
                    .safeAreaInset(edge: .bottom) {
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
                    .frame(minWidth: 560, minHeight: 420)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            DiagnosticsLogListView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(store.visibleEntries.isEmpty ? 0 : 1)

            if store.isLoading && store.visibleEntries.isEmpty {
                ProgressView(L10n.tr("diagnostics.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
            .frame(minHeight: 260)
        #endif
        .layoutPriority(1)
    }
}

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
                selectedLevel: nil,
                maxEntries: 2
            )
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = .placeholder
        }
    )
}
