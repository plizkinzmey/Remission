import Dependencies
import DependenciesMacros
import Foundation

/// Поставщик магнит-ссылок из буфера обмена или deeplink-очереди.
@DependencyClient
struct MagnetLinkClient: Sendable {
    var consumePendingMagnet: @Sendable () async throws -> String?
}

extension MagnetLinkClient: DependencyKey {
    static let liveValue: Self = Self(
        consumePendingMagnet: {
            nil
        }
    )

    static let previewValue: Self = liveValue
    static let testValue: Self = liveValue
}

extension DependencyValues {
    var magnetLinkClient: MagnetLinkClient {
        get { self[MagnetLinkClient.self] }
        set { self[MagnetLinkClient.self] = newValue }
    }
}
