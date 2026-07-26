import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class TorrentListNotificationTests: XCTestCase {
    let serverID = ServerConnectionEnvironment.testServerID
    func testNotification_OnCompletion() async {
        let clock = TestClock()
        let torrentID = Torrent.Identifier(rawValue: 1)

        let oldTorrent = Torrent(
            id: torrentID,
            name: "Test Movie",
            status: .downloading,
            summary: .init(
                progress: .init(
                    percentDone: 0.9, recheckProgress: 0, totalSize: 1000, downloadedEver: 900,
                    uploadedEver: 0, uploadRatio: 0, etaSeconds: 10),
                transfer: .init(
                    downloadRate: 100, uploadRate: 0,
                    downloadLimit: .init(isEnabled: false, kilobytesPerSecond: 0),
                    uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 0)),
                peers: .init(connected: 5, sources: [])
            )
        )

        var newTorrent = oldTorrent
        newTorrent.summary.progress.percentDone = 1.0
        newTorrent.status = .seeding

        let notificationSent = expectation(description: "Notification sent")
        let notificationConfirmation = SendableExpectation(notificationSent)
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                items: [TorrentListItem.State(torrent: oldTorrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.notificationClient.sendNotification = { @Sendable title, body, _ in
                XCTAssertEqual(title, L10n.tr("torrentList.notification.completed.title"))
                XCTAssertEqual(
                    body,
                    L10n.tr("torrentList.notification.completed.body", "Test Movie")
                )
                notificationConfirmation.fulfill()
            }
        }
        store.exhaustivity = .off

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [newTorrent],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(.torrentsResponse(.success(payload)))

        await fulfillment(of: [notificationSent], timeout: 1)
        // Give the fire-and-forget effect time to run
        for _ in 0..<10 {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(10))
            await Task.yield()
        }
    }
    func testNotification_OnError() async {
        let clock = TestClock()
        let torrentID = Torrent.Identifier(rawValue: 1)

        let oldTorrent = Torrent(
            id: torrentID,
            name: "Test Movie",
            status: .downloading,
            summary: .init(
                progress: .init(
                    percentDone: 0.5, recheckProgress: 0, totalSize: 1000, downloadedEver: 500,
                    uploadedEver: 0, uploadRatio: 0, etaSeconds: 10),
                transfer: .init(
                    downloadRate: 100, uploadRate: 0,
                    downloadLimit: .init(isEnabled: false, kilobytesPerSecond: 0),
                    uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 0)),
                peers: .init(connected: 5, sources: [])
            )
        )

        var newTorrent = oldTorrent
        newTorrent.error = 3
        newTorrent.errorString = "Disk full"

        let notificationSent = expectation(description: "Notification sent")
        let notificationConfirmation = SendableExpectation(notificationSent)
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                items: [TorrentListItem.State(torrent: oldTorrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.notificationClient.sendNotification = { @Sendable title, body, _ in
                XCTAssertEqual(title, L10n.tr("torrentList.notification.error.title"))
                XCTAssertEqual(body, "Disk full")
                notificationConfirmation.fulfill()
            }
        }
        store.exhaustivity = .off

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [newTorrent],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(.torrentsResponse(.success(payload)))

        await fulfillment(of: [notificationSent], timeout: 1)
        // Give the fire-and-forget effect time to run
        for _ in 0..<10 {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(10))
            await Task.yield()
        }
    }
    func testNotification_NoChange() async {
        let clock = TestClock()
        let torrent = Torrent.previewDownloading

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                items: [TorrentListItem.State(torrent: torrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.notificationClient.sendNotification = { @Sendable _, _, _ in
                XCTFail("Notification should not be sent")
            }
        }
        store.exhaustivity = .off

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [torrent],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(.torrentsResponse(.success(payload)))

        // Give it a small time to run the effect
        try? await Task.sleep(for: .milliseconds(100))
    }
    func testNotification_NoInitialLoadNotifications() async {
        let clock = TestClock()
        let completed = Torrent.previewCompleted
        var errored = Torrent.previewDownloading
        errored.error = 2
        errored.errorString = "Disk full"

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                phase: .loading,
                items: []
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.notificationClient.sendNotification = { @Sendable _, _, _ in
                XCTFail("Notification should not be sent on initial load")
            }
        }
        store.exhaustivity = .off

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [completed, errored],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(.torrentsResponse(.success(payload)))
        try? await Task.sleep(for: .milliseconds(100))
    }
    func testNotification_NewTorrentAfterLoaded() async {
        let clock = TestClock()
        let existing = Torrent.previewDownloading
        var newCompleted = Torrent.previewCompleted
        newCompleted.id = Torrent.Identifier(rawValue: 777)
        newCompleted.name = "New Download"

        let notificationSent = expectation(description: "Notification sent")
        let notificationConfirmation = SendableExpectation(notificationSent)
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: existing)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.notificationClient.sendNotification = { @Sendable title, body, identifier in
                XCTAssertEqual(title, L10n.tr("torrentList.notification.completed.title"))
                XCTAssertEqual(
                    body,
                    L10n.tr("torrentList.notification.completed.body", "New Download")
                )
                XCTAssertEqual(identifier, "completed-777")
                notificationConfirmation.fulfill()
            }
        }
        store.exhaustivity = .off

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [existing, newCompleted],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(.torrentsResponse(.success(payload)))

        await fulfillment(of: [notificationSent], timeout: 1)
        for _ in 0..<10 {
            if Task.isCancelled { break }
            try? await Task.sleep(for: .milliseconds(10))
            await Task.yield()
        }
    }
}

private final class SendableExpectation: @unchecked Sendable {
    private let expectation: XCTestExpectation

    init(_ expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func fulfill() {
        expectation.fulfill()
    }
}
