import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AddTorrentSourceFeatureTests {
    @Test
    func continueWithValidMagnetSendsDelegate() async {
        let store = TestStore(
            initialState: AddTorrentSourceReducer.State(source: .magnetLink)
        ) {
            AddTorrentSourceReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.magnetTextChanged("magnet:?xt=urn:btih:demo")) {
            $0.magnetText = "magnet:?xt=urn:btih:demo"
        }

        await store.send(.continueTapped)
        await store.receive(.delegate(.magnetSubmitted("magnet:?xt=urn:btih:demo")))
    }

    @Test
    func invalidMagnetShowsAlert() async {
        let store = TestStore(
            initialState: AddTorrentSourceReducer.State(source: .magnetLink)
        ) {
            AddTorrentSourceReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
        }

        await store.send(.magnetTextChanged("http://example.com")) {
            $0.magnetText = "http://example.com"
        }

        await store.send(.continueTapped) {
            $0.alert = AlertState {
                TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("serverDetail.addTorrent.invalidMagnet.message"))
            }
        }
    }

    @Test
    func pasteWithoutMagnetShowsAlert() async {
        let store = TestStore(
            initialState: AddTorrentSourceReducer.State(source: .magnetLink)
        ) {
            AddTorrentSourceReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.magnetLinkClient = MagnetLinkClient(
                consumePendingMagnet: { nil }
            )
        }

        await store.send(.pasteFromClipboardTapped)
        await store.receive(.pasteResponse(.success(nil))) {
            $0.alert = AlertState {
                TextState(L10n.tr("torrentAdd.source.noMagnet.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("torrentAdd.source.noMagnet.message"))
            }
        }
    }
}
