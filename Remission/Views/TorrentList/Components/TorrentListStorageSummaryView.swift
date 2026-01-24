import ComposableArchitecture
import SwiftUI

struct TorrentListStorageSummaryView: View {
    let summary: StorageSummary?
    #if os(macOS)
        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif

    var body: some View {
        if let summary {
            let total = StorageFormatters.bytes(summary.totalBytes)
            let free = StorageFormatters.bytes(summary.freeBytes)
            Label(
                String(format: L10n.tr("storage.summary"), total, free),
                systemImage: "externaldrive.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            #if os(macOS)
                .frame(height: macOSToolbarPillHeight)
            #else
                .frame(height: 34)
            #endif
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
            .accessibilityIdentifier("torrent_list_storage_summary")
        }
    }
}
