import Dependencies
import DependenciesMacros
import Foundation

/// Чтение .torrent файла из выбранного URL.
@DependencyClient
struct TorrentFileLoaderDependency: Sendable {
    var load: @Sendable (_ url: URL) throws -> Data
}

extension TorrentFileLoaderDependency: DependencyKey {
    static let liveValue: Self = Self(
        load: { url in
            #if os(macOS)
                let didStartAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            #endif

            return try Data(contentsOf: url, options: [.mappedIfSafe])
        }
    )

    static let previewValue: Self = liveValue
    static let testValue: Self = Self(
        load: { _ in Data() }
    )
}

extension DependencyValues {
    var torrentFileLoader: TorrentFileLoaderDependency {
        get { self[TorrentFileLoaderDependency.self] }
        set { self[TorrentFileLoaderDependency.self] = newValue }
    }
}
