import Dependencies
import DependenciesMacros
import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// Поставщик магнит-ссылок из буфера обмена или deeplink-очереди.
@DependencyClient
struct MagnetLinkClient: Sendable {
    var consumePendingMagnet: @Sendable () async throws -> String?
}

extension MagnetLinkClient: DependencyKey {
    static let liveValue: Self = Self(
        consumePendingMagnet: {
            extractMagnetLink(from: currentPasteboardString())
        }
    )

    static let previewValue: Self = liveValue
    static let testValue: Self = liveValue
}

private func currentPasteboardString() -> String? {
    #if os(iOS)
        return UIPasteboard.general.string
    #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
    #else
        return nil
    #endif
}

func extractMagnetLink(from value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return nil }

    if let range = trimmed.range(of: "magnet:", options: [.caseInsensitive]) {
        let tail = String(trimmed[range.lowerBound...])
        let token = tail.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first
        let candidate = token.map(String.init) ?? tail
        guard let url = URL(string: candidate), url.scheme?.lowercased() == "magnet" else {
            return nil
        }
        return candidate
    }

    return nil
}

extension DependencyValues {
    var magnetLinkClient: MagnetLinkClient {
        get { self[MagnetLinkClient.self] }
        set { self[MagnetLinkClient.self] = newValue }
    }
}
