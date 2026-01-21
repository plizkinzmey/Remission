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
            filterSection
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

    private var filterSection: some View {
        AppSectionCard(L10n.tr("diagnostics.level")) {
            fieldRow(label: L10n.tr("diagnostics.level")) {
                Picker(
                    "",
                    selection: Binding<AppLogLevel?>(
                        get: { store.selectedLevel },
                        set: { store.send(.levelSelected($0)) }
                    )
                ) {
                    Text(L10n.tr("diagnostics.level.all")).tag(AppLogLevel?.none)
                    ForEach(diagnosticsLevelOptions, id: \.self) { level in
                        Text(diagnosticsLevelLabel(level)).tag(AppLogLevel?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("diagnostics_level_picker")
                .tint(AppTheme.accent)
                #if os(macOS)
                    .controlSize(.large)
                #endif
            }

            Divider()

            TextField(
                L10n.tr("diagnostics.search.placeholder"),
                text: Binding(
                    get: { store.query },
                    set: { store.send(.queryChanged($0)) }
                )
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .appPillSurface()
            .accessibilityIdentifier("diagnostics_search_field")
        }
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

    private var logList: some View {
        List {
            ForEach(store.visibleEntries) { entry in
                let isLast = entry.id == store.visibleEntries.last?.id
                logRow(entry)
                    .listRowInsets(.init(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowBackground(Color.clear)
                    .onAppear {
                        if isLast {
                            store.send(.loadMoreIfNeeded)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }

    private func logRow(_ entry: DiagnosticsLogEntry) -> some View {
        let metadata = DiagnosticsLogFormatter.metadataTags(for: entry)
        let errorSummary = DiagnosticsLogFormatter.errorSummary(for: entry)
        let isOffline = DiagnosticsLogFormatter.isOffline(entry)
        let isNetworkIssue = DiagnosticsLogFormatter.isNetworkIssue(entry)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                levelBadge(for: entry.level)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                    Text(entry.category)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(diagnosticsTimeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            networkBadge(isOffline: isOffline, isNetworkIssue: isNetworkIssue)

            if let errorSummary {
                Text(errorSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("diagnostics_error_summary_\(entry.id.uuidString)")
            }

            if metadata.isEmpty == false {
                metadataRow(metadata)
            }
        }
        .padding(.vertical, 2)
        .contextMenu { copyButton(for: entry) }
        #if os(iOS)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                copyButton(for: entry)
            }
        #endif
        .accessibilityIdentifier("diagnostics_log_row_\(entry.id.uuidString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
        .overlay(alignment: .topLeading) {
            accessibilityOverlay(isOffline: isOffline, isNetworkIssue: isNetworkIssue)
        }
    }

    private func copyButton(for entry: DiagnosticsLogEntry) -> some View {
        Button {
            store.send(.copyEntry(entry))
        } label: {
            Label(L10n.tr("diagnostics.copy"), systemImage: "doc.on.doc")
        }
        .tint(.accentColor)
        .accessibilityIdentifier("diagnostics_copy_\(entry.id.uuidString)")
    }

    private func metadataRow(_ metadata: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metadata, id: \.self) { item in
                    metadataBadge(item)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func accessibilityOverlay(isOffline: Bool, isNetworkIssue: Bool) -> some View {
        Group {
            if isOffline {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("diagnostics_offline_badge")
            } else if isNetworkIssue {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("diagnostics_network_badge")
            }
        }
    }

    @ViewBuilder
    private func networkBadge(isOffline: Bool, isNetworkIssue: Bool) -> some View {
        if isOffline || isNetworkIssue {

            let title =
                isOffline
                ? L10n.tr("diagnostics.offline.badge")
                : L10n.tr("diagnostics.network.badge")

            let imageName = isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
            let color: Color = isOffline ? .red : .orange

            Label(title, systemImage: imageName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityIdentifier(
                    isOffline ? "diagnostics_offline_badge" : "diagnostics_network_badge"
                )
                .overlay(
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .accessibilityHidden(false)
                        .accessibilityIdentifier(
                            isOffline
                                ? "diagnostics_offline_badge_marker"
                                : "diagnostics_network_badge_marker"
                        )
                )
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
            )
            .accessibilityLabel(text)
            .accessibilityIdentifier("diagnostics_metadata_\(text)")
    }

    private var logContent: some View {
        ZStack {
            logList
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

    private func fieldRow<Content: View>(
        label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            field()
                .frame(maxWidth: 360, alignment: .trailing)
        }
    }

    private func accessibilityLabel(for entry: DiagnosticsLogEntry) -> String {
        var label = String(
            format: L10n.tr("%@, %@: %@"),
            locale: Locale.current,
            diagnosticsTimeFormatter.string(from: entry.timestamp),
            diagnosticsLevelLabel(entry.level),
            entry.message
        )
        if DiagnosticsLogFormatter.isOffline(entry) {
            label.append(", \(L10n.tr("diagnostics.offline.badge"))")
        }
        return label
    }

    private var exportText: String? {
        let entries = store.entries.elements
        guard entries.isEmpty == false else { return nil }
        return DiagnosticsLogFormatter.copyText(for: entries)
    }

    private func levelBadge(for level: AppLogLevel) -> some View {
        Text(diagnosticsLevelLabel(level).uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(diagnosticsLevelColor(level).opacity(0.15))
            .foregroundStyle(diagnosticsLevelColor(level))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("diagnostics_level_badge_\(level.rawValue)")
    }
}

private let diagnosticsLevelOptions: [AppLogLevel] = [.error, .warning, .info, .debug]

private func diagnosticsLevelLabel(_ level: AppLogLevel) -> String {
    switch level {
    case .debug: return L10n.tr("diagnostics.level.debug")
    case .info: return L10n.tr("diagnostics.level.info")
    case .warning: return L10n.tr("diagnostics.level.warn")
    case .error: return L10n.tr("diagnostics.level.error")
    }
}

private func diagnosticsLevelColor(_ level: AppLogLevel) -> Color {
    switch level {
    case .debug: return .blue
    case .info: return .green
    case .warning: return .orange
    case .error: return .red
    }
}

private let diagnosticsTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter
}()

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
