import SwiftUI
import Testing

@testable import Remission

@Suite("View Smoke Tests")
@MainActor
struct ViewSmokeTests {
    @Test
    func appLabeledValueViewRendersAllLayouts() {
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

    @Test
    func appTagViewRendersWithCustomStyle() {
        let view = AppTagView(text: "Downloading", color: .blue, opacity: 0.12)
        _ = view.body
    }

    @Test
    func appTorrentActionButtonRendersBusyAndIdle() {
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
