import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Torrent List Header iOS View Tests")
@MainActor
struct TorrentListHeaderiOSViewTests {
    @Test
    func headerRendersWithDifferentFilters() {
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

    @Test
    func headerRendersWithDifferentCategories() {
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

    @Test
    func headerRendersWithoutStorageSummary() {
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
