import SwiftUI

struct TorrentRowBackgroundView: View {
    let isIsolated: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fillColor: Color =
            isIsolated
            ? Color.red.opacity(0.08)
            : Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.06)
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
    }
}
