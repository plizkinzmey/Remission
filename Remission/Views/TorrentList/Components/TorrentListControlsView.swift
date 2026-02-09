import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct TorrentListControlsView: View {
    @Bindable var store: StoreOf<TorrentListReducer>
    @State private var searchText: String = ""

    #if os(iOS)
        // Match the iPad "status filters" capsule visual height.
        private var controlsPillHeight: CGFloat { 30 }
        private var controlsPillInnerPadding: CGFloat { 2 }
    #else
        private var controlsPillHeight: CGFloat { 34 }
        private var controlsPillInnerPadding: CGFloat { 2 }
    #endif

    #if os(macOS)
        private var macOSCategoryPickerWidth: CGFloat { 170 }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Row 1: Filter segmented control
            HStack {
                Spacer()
                #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        filterCapsules
                    } else {
                        filterSegmentedControl
                            .labelsHidden()
                            .controlSize(.small)
                    }
                #else
                    filterSegmentedControl
                        .labelsHidden()
                        .controlSize(.large)
                #endif
                Spacer()
            }

            #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad && store.isSearchFieldVisible {
                    searchFieldView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            #endif

            // Row 2: Category picker
            HStack {
                Spacer(minLength: 0)
                categoryPicker
                Spacer(minLength: 0)
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
    }

    #if os(iOS)
        private var searchToggleButton: some View {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    _ = store.send(.toggleSearchField)
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }

        private var filterCapsules: some View {
            HStack {
                HStack(spacing: 4) {
                    filterSegmentedControlPad
                    searchToggleButton
                }
                .padding(controlsPillInnerPadding)
                .frame(height: controlsPillHeight)
                .appInteractivePillSurface()
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
            .padding(.horizontal, 10)
            .frame(height: controlsPillHeight)
            .appInteractivePillSurface()
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

    private var categoryPicker: some View {
        Menu {
            ForEach(TorrentListReducer.CategoryFilter.allCases, id: \.self) { category in
                Button(category.title) {
                    store.send(.categoryChanged(category))
                }
            }
        } label: {
            #if os(macOS)
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
                .frame(width: macOSCategoryPickerWidth, height: controlsPillHeight)
                .contentShape(Rectangle())
                .appInteractivePillSurface()
            #else
                HStack(spacing: 8) {
                    Text(store.selectedCategory.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: controlsPillHeight)
                .contentShape(Rectangle())
                .appInteractivePillSurface()
                .fixedSize(horizontal: true, vertical: false)
            #endif
        }
        .accessibilityIdentifier("torrentlist_category_picker")
        .buttonStyle(.plain)
    }
}
