import ComposableArchitecture
import SwiftUI

struct DiagnosticsLogListView: View {
    let store: StoreOf<DiagnosticsReducer>

    var body: some View {
        List {
            ForEach(store.visibleEntries) { entry in
                let isLast = entry.id == store.visibleEntries.last?.id
                DiagnosticsLogRowView(
                    entry: entry,
                    onCopy: { store.send(.copyEntry(entry)) }
                )
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
}
