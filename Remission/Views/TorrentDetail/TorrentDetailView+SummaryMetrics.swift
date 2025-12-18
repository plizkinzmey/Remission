import SwiftUI

struct SummaryMetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@: %@"),
                locale: Locale.current,
                title,
                value
            )
        )
    }
}

struct SummaryMetricCompactRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
    }
}
