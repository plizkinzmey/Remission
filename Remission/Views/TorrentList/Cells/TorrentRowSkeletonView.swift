import SwiftUI

struct TorrentRowSkeletonView: View {
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 16)
                Spacer(minLength: 20)
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 72, height: 16)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
        .redacted(reason: .placeholder)
        .accessibilityIdentifier("torrent_row_skeleton_\(index)")
    }
}
