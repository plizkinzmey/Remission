import ComposableArchitecture
import SwiftUI

struct TorrentListControlsView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    #if os(macOS)
        private var macOSSortPickerWidth: CGFloat { 150 }
        private var macOSCategoryPickerWidth: CGFloat { 170 }
        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif

    var body: some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 12) {
                filterAndSortRowMacOS
            }
            .padding(.vertical, 4)
        #else
            VStack(alignment: .leading, spacing: 12) {
                filterSegmentedControl
                HStack(spacing: 12) {
                    if store.visibleItems.isEmpty == false {
                        categoryPicker
                    }
                    Spacer(minLength: 0)
                    if store.visibleItems.isEmpty == false {
                        sortPicker
                    }
                }
            }
            .padding(.vertical, 4)
        #endif
    }

    #if os(macOS)
        private var filterAndSortRowMacOS: some View {
            HStack(alignment: .center, spacing: 12) {
                categoryPicker
                    .labelsHidden()
                    .frame(width: macOSCategoryPickerWidth)

                Spacer(minLength: 0)

                filterSegmentedControl
                    .labelsHidden()
                    .frame(maxWidth: 360)

                Spacer(minLength: 0)

                sortPicker
                    .labelsHidden()
                    .frame(width: macOSSortPickerWidth)
            }
        }
    #endif

    private var filterSegmentedControl: some View {
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
        .accessibilityIdentifier("torrentlist_filter_picker")
        .pickerStyle(.segmented)
        .foregroundStyle(.primary)
        #if os(macOS)
            .controlSize(.large)
        #endif
    }

    private var sortPicker: some View {
        #if os(macOS)
            Menu {
                ForEach(TorrentListReducer.SortOrder.allCases, id: \.self) { sort in
                    Button(sort.title) {
                        store.send(.sortChanged(sort))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(store.sortOrder.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(width: macOSSortPickerWidth, height: macOSToolbarPillHeight)
                .contentShape(Rectangle())
                .appToolbarPillSurface()
            }
            .accessibilityIdentifier("torrentlist_sort_picker")
            .buttonStyle(.plain)
        #else
            Picker(
                L10n.tr("torrentList.sort.title"),
                selection: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortChanged($0)) }
                )
            ) {
                ForEach(TorrentListReducer.SortOrder.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .accessibilityIdentifier("torrentlist_sort_picker")
            .pickerStyle(.menu)
        #endif
    }

    private var categoryPicker: some View {
        #if os(macOS)
            Menu {
                ForEach(TorrentListReducer.CategoryFilter.allCases, id: \.self) { category in
                    Button(category.title) {
                        store.send(.categoryChanged(category))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(store.selectedCategory.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(width: macOSCategoryPickerWidth, height: macOSToolbarPillHeight)
                .contentShape(Rectangle())
                .appToolbarPillSurface()
            }
            .accessibilityIdentifier("torrentlist_category_picker")
            .buttonStyle(.plain)
        #else
            Picker(
                L10n.tr("torrentList.category.title"),
                selection: Binding(
                    get: { store.selectedCategory },
                    set: { store.send(.categoryChanged($0)) }
                )
            ) {
                ForEach(TorrentListReducer.CategoryFilter.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }
            .accessibilityIdentifier("torrentlist_category_picker")
            .pickerStyle(.menu)
        #endif
    }
}
