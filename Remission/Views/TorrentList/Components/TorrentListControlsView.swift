import ComposableArchitecture
import SwiftUI

struct TorrentListControlsView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                filterPicker
                    .frame(maxWidth: 420)
                categoryPicker
            }

            VStack(alignment: .leading, spacing: 8) {
                filterPicker
                categoryPicker
            }
        }
        .accessibilityIdentifier("torrentlist_controls")
    }

    private var filterPicker: some View {
        Picker(
            L10n.tr("torrentList.filter.title"),
            selection: Binding(
                get: { store.selectedFilter },
                set: { store.send(.filterChanged($0)) }
            )
        ) {
            ForEach(TorrentListReducer.Filter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("torrentlist_filter_picker")
    }

    private var categoryPicker: some View {
        Picker(
            L10n.tr("torrentAdd.section.category"),
            selection: Binding(
                get: { store.selectedCategory },
                set: { store.send(.categoryChanged($0)) }
            )
        ) {
            ForEach(TorrentListReducer.CategoryFilter.allCases, id: \.self) { category in
                Text(category.title).tag(category)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.regular)
        .accessibilityIdentifier("torrentlist_category_picker")
    }
}
