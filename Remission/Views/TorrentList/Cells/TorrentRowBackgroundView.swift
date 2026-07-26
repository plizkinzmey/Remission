import SwiftUI

struct TorrentRowBackgroundView: View {
    let isIsolated: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fillColor: Color =
            isIsolated
            ? .red.opacity(0.08)
            : .secondary.opacity(colorScheme == .dark ? 0.16 : 0.08)
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .appFlatCardSurface(cornerRadius: 10)
    }
}
