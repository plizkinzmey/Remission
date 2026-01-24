import SwiftUI

struct TorrentDetailLabelValueRow: View {
    let label: String
    let value: String
    var monospacedValue: Bool = false

    var body: some View {
        AppLabeledValueView(
            label: label,
            value: value,
            layout: .adaptive,
            monospacedValue: monospacedValue
        )
    }
}
