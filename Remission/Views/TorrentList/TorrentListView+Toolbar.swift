import ComposableArchitecture
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

extension TorrentListView {
    #if os(macOS)
        var macOSToolbarControls: some View {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                    TextField(
                        L10n.tr("torrentList.search.prompt"),
                        text: .init(
                            get: { store.searchQuery },
                            set: { store.send(.searchQueryChanged($0)) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("torrentlist_search_field")
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 300, idealWidth: 420, maxWidth: 520)
            .frame(height: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(toolbarCapsuleTint)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                AppTheme.Stroke.subtle(themeColorScheme).opacity(0.55),
                                lineWidth: 1
                            )
                    )
            )
        }
    #endif

    #if os(iOS)
        var shouldShowSearchBar: Bool {
            if UIDevice.current.userInterfaceIdiom == .pad { return false }
            guard store.connectionEnvironment != nil else { return false }
            return store.visibleItems.isEmpty == false || store.searchQuery.isEmpty == false
        }
    #endif
}

#if os(macOS)
    extension TorrentListView {
        fileprivate var toolbarCapsuleTint: Color {
            switch themeColorScheme {
            case .dark:
                return Color.black.opacity(0.35)
            case .light:
                return Color.white.opacity(0.35)
            @unknown default:
                return Color.black.opacity(0.35)
            }
        }

        fileprivate var toolbarInnerCapsuleFill: Color {
            switch themeColorScheme {
            case .dark:
                return Color.black.opacity(0.65)
            case .light:
                return Color.black.opacity(0.10)
            @unknown default:
                return Color.black.opacity(0.65)
            }
        }

        fileprivate var toolbarInnerCapsuleStroke: Color {
            switch themeColorScheme {
            case .dark:
                return Color.white.opacity(0.16)
            case .light:
                return Color.white.opacity(0.45)
            @unknown default:
                return Color.white.opacity(0.16)
            }
        }
    }
#endif
