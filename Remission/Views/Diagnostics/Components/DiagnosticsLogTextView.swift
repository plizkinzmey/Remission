import ComposableArchitecture
import SwiftUI

struct DiagnosticsLogTextView: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(jsonString)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if store.entries.count > store.visibleCount {
                    Button(L10n.tr("diagnostics.loadMore")) {
                        store.send(.loadMoreIfNeeded)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
            }
            .padding()
        }
        #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
        #endif
    }

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let entries = store.visibleEntries

        guard let data = try? encoder.encode(entries),
            let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }
}
