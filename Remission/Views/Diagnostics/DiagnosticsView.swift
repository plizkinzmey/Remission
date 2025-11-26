import ComposableArchitecture
import SwiftUI

struct DiagnosticsView: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                filterBar
                    .padding(.horizontal)

                if store.isLoading && store.entries.isEmpty {
                    ProgressView(L10n.tr("diagnostics.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.entries.isEmpty {
                    ContentUnavailableView(
                        L10n.tr("diagnostics.empty.title"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(
                            L10n.tr("diagnostics.empty.message"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    logList
                }
            }
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
            .task { await store.send(.task).finish() }
            .onDisappear {
                store.send(.teardown)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(
                L10n.tr("diagnostics.level"),
                selection: Binding<AppLogLevel?>(
                    get: { store.selectedLevel },
                    set: { store.send(.levelSelected($0)) }
                )
            ) {
                Text(L10n.tr("diagnostics.level.all")).tag(AppLogLevel?.none)
                ForEach(levelOptions, id: \.self) { level in
                    Text(levelLabel(level)).tag(AppLogLevel?.some(level))
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("diagnostics_level_picker")

            TextField(
                L10n.tr("diagnostics.search.placeholder"),
                text: Binding(
                    get: { store.query },
                    set: { store.send(.queryChanged($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("diagnostics_search_field")
        }
    }

    private var logList: some View {
        List {
            Section {
                ForEach(store.entries) { entry in
                    logRow(entry)
                        .listRowInsets(.init(top: 10, leading: 12, bottom: 10, trailing: 12))
                }
            }
        }
        .listStyle(.plain)
    }

    private func logRow(_ entry: DiagnosticsLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                levelBadge(for: entry.level)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    Text(entry.category)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if metadataHighlights(for: entry).isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(metadataHighlights(for: entry), id: \.self) { item in
                            Text(item)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.12))
                                )
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("diagnostics_log_row_\(entry.id.uuidString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(timeFormatter.string(from: entry.timestamp)), \(levelLabel(entry.level)): \(entry.message)"
        )
    }

    private func levelBadge(for level: AppLogLevel) -> some View {
        Text(levelLabel(level).uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(levelColor(level).opacity(0.15))
            .foregroundStyle(levelColor(level))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("diagnostics_level_badge_\(level.rawValue)")
    }

    private func levelLabel(_ level: AppLogLevel) -> String {
        switch level {
        case .debug: return L10n.tr("diagnostics.level.debug")
        case .info: return L10n.tr("diagnostics.level.info")
        case .warning: return L10n.tr("diagnostics.level.warn")
        case .error: return L10n.tr("diagnostics.level.error")
        }
    }

    private var levelOptions: [AppLogLevel] {
        [.error, .warning, .info, .debug]
    }

    private func levelColor(_ level: AppLogLevel) -> Color {
        switch level {
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func metadataHighlights(for entry: DiagnosticsLogEntry) -> [String] {
        var highlights: [String] = []

        if let method = entry.metadata["method"] {
            highlights.append(method)
        }
        if let status = entry.metadata["status"] {
            highlights.append("status \(status)")
        }
        if let host = entry.metadata["host"] {
            highlights.append(host)
        }
        if let path = entry.metadata["path"] {
            highlights.append(path)
        }
        if let server = entry.metadata["server"] {
            highlights.append("server \(server)")
        }
        if let elapsed = entry.metadata["elapsed_ms"] {
            highlights.append("\(elapsed) ms")
        }
        return highlights
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
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
                                "host": "nas.local"
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
                selectedLevel: nil
            )
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = .placeholder
        }
    )
}
