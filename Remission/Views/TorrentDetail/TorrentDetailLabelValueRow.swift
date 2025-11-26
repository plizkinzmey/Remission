import SwiftUI

struct TorrentDetailLabelValueRow: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@: %@"),
                locale: Locale.current,
                label,
                value
            )
        )
    }
}
