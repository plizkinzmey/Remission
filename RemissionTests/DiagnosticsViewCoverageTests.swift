import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Diagnostics View Coverage")
@MainActor
struct DiagnosticsViewCoverageTests {
    private func makeEntry(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        level: AppLogLevel = .error
    ) -> DiagnosticsLogEntry {
        DiagnosticsLogEntry(
            id: id,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            level: level,
            message: "Connection failed",
            category: "network",
            metadata: ["error": "timeout"]
        )
    }

    private func makeStore(entries: [DiagnosticsLogEntry]) -> StoreOf<DiagnosticsReducer> {
        var state = DiagnosticsReducer.State()
        state.entries = IdentifiedArrayOf(uniqueElements: entries)
        state.visibleCount = entries.count
        return Store(initialState: state) {
            DiagnosticsReducer()
        }
    }

    @Test
    func diagnosticsBadgesRender() {
        let levelBadge = DiagnosticsLevelBadge(level: .warning)
        let offline = DiagnosticsNetworkBadge(isOffline: true, isNetworkIssue: false)
        let network = DiagnosticsNetworkBadge(isOffline: false, isNetworkIssue: true)
        _ = levelBadge.body
        _ = offline.body
        _ = network.body
    }

    @Test
    func diagnosticsLogRowAndDetailsRender() {
        let entry = makeEntry()
        let row = DiagnosticsLogRowView(entry: entry, onCopy: {})
        let details = DiagnosticsLogDetailsSheet(entry: entry)
        _ = row.body
        _ = details.body
    }

    @Test
    func diagnosticsFilterListTextAndRootViewsRender() {
        let entry = makeEntry()
        let store = makeStore(entries: [entry])

        _ = DiagnosticsFilterSection(store: store).body
        _ = DiagnosticsLogListView(store: store).body
        _ = DiagnosticsLogTextView(store: store).body
        _ = DiagnosticsView(store: store).body
    }
}
