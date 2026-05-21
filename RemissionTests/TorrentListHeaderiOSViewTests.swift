import ComposableArchitecture
import SwiftUI
import XCTest

@testable import Remission

@MainActor
final class TorrentListHeaderiOSViewTests: XCTestCase {
    func testHeaderRendersWithDifferentFilters() {
        for filter in TorrentListReducer.Filter.allCases {
            let store = Store(
                initialState: TorrentListReducer.State(
                    selectedFilter: filter,
                    storageSummary: .init(totalBytes: 2048, freeBytes: 1024)
                )
            ) {
                TorrentListReducer()
            }

            let view = TorrentListHeaderiOSView(store: store)
            _ = view.body
        }
    }

    func testHeaderRendersWithDifferentCategories() {
        for category in TorrentListReducer.CategoryFilter.allCases {
            let store = Store(
                initialState: TorrentListReducer.State(
                    selectedCategory: category
                )
            ) {
                TorrentListReducer()
            }

            let view = TorrentListHeaderiOSView(store: store)
            _ = view.body
        }
    }

    func testHeaderRendersWithoutStorageSummary() {
        let store = Store(
            initialState: TorrentListReducer.State(
                storageSummary: nil
            )
        ) {
            TorrentListReducer()
        }

        let view = TorrentListHeaderiOSView(store: store)
        _ = view.body
    }
}
