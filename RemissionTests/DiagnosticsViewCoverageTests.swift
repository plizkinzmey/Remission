import ComposableArchitecture
import SwiftUI
import XCTest

@testable import Remission

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

@MainActor
final class DiagnosticsViewCoverageTests: XCTestCase {
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
    func testDiagnosticsBadgesRender() {
        let levelBadge = DiagnosticsLevelBadge(level: .warning)
        let offline = DiagnosticsNetworkBadge(isOffline: true, isNetworkIssue: false)
        let network = DiagnosticsNetworkBadge(isOffline: false, isNetworkIssue: true)
        host(levelBadge)
        host(offline)
        host(network)
    }
    func testDiagnosticsLogRowAndDetailsRender() {
        let entry = makeEntry()
        let row = DiagnosticsLogRowView(entry: entry, onCopy: {})
        let details = DiagnosticsLogDetailsSheet(entry: entry)
        host(row)
        host(details)
    }
    func testDiagnosticsFilterListTextAndRootViewsRender() {
        let entry = makeEntry()
        let store = makeStore(entries: [entry])
        host(DiagnosticsFilterSection(store: store))
        host(DiagnosticsLogListView(store: store))
        host(DiagnosticsLogTextView(store: store))
        host(DiagnosticsView(store: store))
    }
}
@MainActor
private func host<V: View>(_ view: V) {
    #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        _ = controller.view
    #elseif canImport(AppKit)
        let controller = NSHostingController(rootView: view)
        _ = controller.view
    #else
        _ = view.body
    #endif
}
