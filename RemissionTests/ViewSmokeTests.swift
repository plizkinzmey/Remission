import SwiftUI
import XCTest

@testable import Remission

@MainActor
final class ViewSmokeTests: XCTestCase {
    func testAppLabeledValueViewRendersAllLayouts() {
        let horizontal = AppLabeledValueView(
            label: "Label",
            value: "Value",
            layout: .horizontal,
            monospacedValue: true
        )
        let vertical = AppLabeledValueView(
            label: "Label",
            value: "Value",
            layout: .vertical,
            monospacedValue: false
        )
        let adaptive = AppLabeledValueView(
            label: "Label",
            value: "Value",
            layout: .adaptive,
            monospacedValue: false
        )

        _ = horizontal.body
        _ = vertical.body
        _ = adaptive.body
    }

    func testAppTagViewRendersWithCustomStyle() {
        let view = AppTagView(text: "Downloading", color: .blue, opacity: 0.12)
        _ = view.body
    }

    func testAppTorrentActionButtonRendersBusyAndIdle() {
        let idle = AppTorrentActionButton(
            type: .start,
            isBusy: false,
            isLocked: false,
            action: {}
        )
        let busy = AppTorrentActionButton(
            type: .pause,
            isBusy: true,
            isLocked: false,
            action: {}
        )

        _ = idle.body
        _ = busy.body
    }
}
