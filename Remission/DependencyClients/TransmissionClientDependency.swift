#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros  // макрос @DependencyClient требует отдельного модуля
    import Foundation

    @DependencyClient
    struct TransmissionClientDependency: Sendable {
        var sessionGet: @Sendable () async throws -> TransmissionResponse
        var sessionSet: @Sendable (AnyCodable) async throws -> TransmissionResponse
        var sessionStats: @Sendable () async throws -> TransmissionResponse
        var torrentGet: @Sendable ([Int]?, [String]?) async throws -> TransmissionResponse
        var torrentAdd:
            @Sendable (
                _ filename: String?,
                _ metainfo: Data?,
                _ downloadDir: String?,
                _ paused: Bool?,
                _ labels: [String]?
            ) async throws -> TransmissionResponse
        var torrentStart: @Sendable ([Int]) async throws -> TransmissionResponse
        var torrentStop: @Sendable ([Int]) async throws -> TransmissionResponse
        var torrentRemove: @Sendable ([Int], Bool?) async throws -> TransmissionResponse
        var torrentSet: @Sendable ([Int], AnyCodable) async throws -> TransmissionResponse
        var torrentVerify: @Sendable ([Int]) async throws -> TransmissionResponse
        var checkServerVersion: @Sendable () async throws -> (compatible: Bool, rpcVersion: Int)
        var performHandshake: @Sendable () async throws -> TransmissionHandshakeResult
    }

    extension TransmissionClientDependency {
        static let placeholder: Self = Self(
            sessionGet: {
                throw TransmissionClientDependencyError.notConfigured("sessionGet")
            },
            sessionSet: { _ in
                throw TransmissionClientDependencyError.notConfigured("sessionSet")
            },
            sessionStats: {
                throw TransmissionClientDependencyError.notConfigured("sessionStats")
            },
            torrentGet: { _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentGet")
            },
            torrentAdd: { _, _, _, _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentAdd")
            },
            torrentStart: { _ in
                throw TransmissionClientDependencyError.notConfigured("torrentStart")
            },
            torrentStop: { _ in
                throw TransmissionClientDependencyError.notConfigured("torrentStop")
            },
            torrentRemove: { _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentRemove")
            },
            torrentSet: { _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentSet")
            },
            torrentVerify: { _ in
                throw TransmissionClientDependencyError.notConfigured("torrentVerify")
            },
            checkServerVersion: {
                throw TransmissionClientDependencyError.notConfigured("checkServerVersion")
            },
            performHandshake: {
                throw TransmissionClientDependencyError.notConfigured("performHandshake")
            }
        )
    }

    enum TransmissionClientDependencyError: Error, LocalizedError, Sendable {
        case notConfigured(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let name):
                return
                    "TransmissionClientDependency.\(name) is not configured for this environment."
            }
        }
    }

    extension TransmissionClientDependency: TestDependencyKey {
        static let testValue: Self = placeholder
        static let previewValue: Self = placeholder
    }

    extension DependencyValues {
        @preconcurrency var transmissionClient: TransmissionClientDependency {
            get { self[TransmissionClientDependency.self] }
            set { self[TransmissionClientDependency.self] = newValue }
        }
    }
#endif
