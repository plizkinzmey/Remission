import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct TorrentListControlsView: View {
    @Bindable var store: StoreOf<TorrentListReducer>
    @State private var searchText: String = ""

    #if os(macOS)
        private var macOSSortPickerWidth: CGFloat { 150 }
        private var macOSCategoryPickerWidth: CGFloat { 170 }
        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif
    #if os(iOS)
        private var padFilterCapsuleHeight: CGFloat { 30 }
        private var padFilterInnerPadding: CGFloat { 2 }
    #endif

    var body: some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 12) {
                filterAndSortRowMacOS
            }
            .padding(.vertical, 4)
        #else
            VStack(alignment: .leading, spacing: 12) {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    filterCapsules

                    if store.isSearchFieldVisible {
                        searchFieldView
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                } else {
                    filterSegmentedControl
                }

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
            .onAppear {
                if searchText != store.searchQuery {
                    searchText = store.searchQuery
                }
            }
            .onChange(of: searchText) { _, newValue in
                guard newValue != store.searchQuery else { return }
                store.send(.searchQueryChanged(newValue))
            }
            .onChange(of: store.searchQuery) { _, newValue in
                guard newValue != searchText else { return }
                searchText = newValue
            }
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

    #if os(iOS)
        private var filterCapsules: some View {
            HStack {
                HStack(spacing: 4) {
                    filterSegmentedControlPad

                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            _ = store.send(.toggleSearchField)
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.isSearchFieldVisible ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(
                                        store.isSearchFieldVisible
                                            ? AppTheme.accent
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(padFilterInnerPadding)
                .frame(height: padFilterCapsuleHeight)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5)
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    #endif

    #if os(iOS)
        private var searchFieldView: some View {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextField(L10n.tr("torrentList.search.prompt"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .submitLabel(.search)

                if searchText.isEmpty == false {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    #if os(iOS)
        private var filterSegmentedControlPad: some View {
            filterSegmentedControl
                .labelsHidden()
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
        }
    #endif

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
