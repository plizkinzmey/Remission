import XCTest

@MainActor
final class TorrentUITests: BaseUITestCase {

    // MARK: - Torrent List Tests

    func testTorrentListSearchAndRefresh() throws {
        #if os(macOS)
            throw XCTSkip(
                "Тест торрент-листа оптимизирован для iOS. На macOS используйте отдельные интеграционные тесты."
            )
        #else
            let app = launchApp(
                arguments: [
                    "--ui-testing-fixture=torrent-list-sample",
                    "--ui-testing-scenario=torrent-list-sample"
                ]
            )
            let serverIdentifier = "server_list_item_AAAA1111-B222-C333-D444-EEEEEEEEEEEE"
            let serverCell = app.buttons[serverIdentifier]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5), "Server cell not found")
            serverCell.tap()

            let torrentsHeader = app.staticTexts["torrent_list_header"]
            XCTAssertTrue(torrentsHeader.waitForExistence(timeout: 5), "Torrent section missing")

            let ubuntuName = app.staticTexts["Ubuntu 25.04 Desktop"]
            XCTAssertTrue(ubuntuName.waitForExistence(timeout: 10))

            let fedoraName = app.staticTexts["Fedora 41 Workstation"]
            XCTAssertTrue(fedoraName.exists)

            let archName = app.staticTexts["Arch Linux Snapshot"]
            XCTAssertTrue(archName.exists)

            let speedSummaryPredicate = NSPredicate(format: "label CONTAINS %@", "↓")
            let speedSummaries = app.staticTexts.matching(speedSummaryPredicate)
            XCTAssertTrue(speedSummaries.count >= 3, "Speed summaries should be visible")

            let progressPredicate = NSPredicate(format: "label CONTAINS %@", "%")
            let progressSummaries = app.staticTexts.matching(progressPredicate)
            XCTAssertTrue(progressSummaries.count >= 3, "Progress values should be visible")

            attachScreenshot(app, name: "torrent_list_fixture")

            let searchField = app.searchFields.firstMatch
            XCTAssertTrue(searchField.waitForExistence(timeout: 4), "Search field not found")
            searchField.clearAndTypeText("Fedora")

            XCTAssertTrue(app.staticTexts["Fedora 41 Workstation"].waitForExistence(timeout: 3))
            XCTAssertTrue(
                app.staticTexts["Ubuntu 25.04 Desktop"].waitForDisappearance(timeout: 6),
                "Other torrents should be filtered out"
            )

            attachScreenshot(app, name: "torrent_list_search_result")
        #endif
    }

    func testTorrentListOfflineBanner() throws {
        #if os(macOS)
            throw XCTSkip("Офлайн баннер проверяется только в iOS среде.")
        #else
            let app = launchApp(
                arguments: [
                    "--ui-testing-fixture=torrent-list-sample",
                    "--ui-testing-scenario=torrent-list-offline"
                ]
            )
            let serverIdentifier = "server_list_item_AAAA1111-B222-C333-D444-EEEEEEEEEEEE"
            let serverCell = app.buttons[serverIdentifier]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5), "Server cell not found")
            serverCell.tap()

            let banner = app.descendants(matching: .any)
                .matching(identifier: "error-banner")
                .firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 8), "Offline banner missing")

            // Retry should be present and tap-able even в офлайне.
            let retryButton = app.buttons["error-banner-retry"]
            if retryButton.exists {
                retryButton.tap()
            }

            attachScreenshot(app, name: "torrent_list_offline_banner")
        #endif
    }

    // MARK: - Torrent Detail Tests

    func testTorrentDetailFlow() throws {
        #if os(macOS)
            throw XCTSkip("Тест детализации торрента выполняется только в iOS среде.")
        #else
            let app = launchApp(
                arguments: [
                    "--ui-testing-fixture=torrent-list-sample",
                    "--ui-testing-scenario=torrent-list-sample"
                ]
            )
            let serverIdentifier = "server_list_item_AAAA1111-B222-C333-D444-EEEEEEEEEEEE"
            let serverCell = app.buttons[serverIdentifier]
            XCTAssertTrue(serverCell.waitForExistence(timeout: 5), "Server cell not found")
            serverCell.tap()

            let torrentsHeader = app.staticTexts["torrent_list_header"]
            XCTAssertTrue(torrentsHeader.waitForExistence(timeout: 5), "Torrent section missing")

            let torrentRowButton = app.buttons["torrent_list_item_1001"]
            XCTAssertTrue(torrentRowButton.waitForExistence(timeout: 5), "Fixture torrent missing")
            torrentRowButton.tap()

            let detailNavBar = app.navigationBars["Ubuntu 25.04 Desktop"]
            XCTAssertTrue(detailNavBar.waitForExistence(timeout: 5), "Detail screen not visible")

            XCTAssertTrue(
                app.otherElements["torrent-summary"].waitForExistence(timeout: 3),
                "Summary section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-main-info"].waitForExistence(timeout: 3),
                "Main info section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-statistics-section"].waitForExistence(timeout: 3),
                "Statistics section missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-speed-history-section"].waitForExistence(timeout: 3),
                "Speed history missing"
            )
            XCTAssertTrue(
                app.otherElements["torrent-actions-section"].waitForExistence(timeout: 3),
                "Actions section missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-pause"].waitForExistence(timeout: 2),
                "Pause command missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-verify"].waitForExistence(timeout: 2),
                "Verify command missing"
            )
            XCTAssertTrue(
                app.buttons["torrent-action-remove"].waitForExistence(timeout: 2),
                "Remove command missing"
            )

            let scrollView = app.scrollViews.firstMatch
            XCTAssertTrue(scrollView.waitForExistence(timeout: 2))

            let filesSection = app.otherElements["torrent-files-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: filesSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Files section missing"
            )

            let trackersSection = app.otherElements["torrent-trackers-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: trackersSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Trackers section missing"
            )

            let peersSection = app.otherElements["torrent-peers-section"]
            XCTAssertTrue(
                waitUntil(
                    timeout: 6,
                    condition: peersSection.exists,
                    onTick: { scrollView.swipeUp() }
                ),
                "Peers section missing"
            )

            attachScreenshot(app, name: "torrent_detail_fixture")
        #endif
    }
}
