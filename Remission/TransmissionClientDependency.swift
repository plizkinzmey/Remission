#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Foundation
    import XCTestDynamicOverlay

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
    }

    extension TransmissionClientDependency {
        fileprivate static let placeholder: Self = Self(
            sessionGet: { throw TransmissionClientDependencyError.notConfigured("sessionGet") },
            sessionSet: { _ in throw TransmissionClientDependencyError.notConfigured("sessionSet")
            },
            sessionStats: { throw TransmissionClientDependencyError.notConfigured("sessionStats") },
            torrentGet: { _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentGet")
            },
            torrentAdd: { _, _, _, _, _ in
                throw TransmissionClientDependencyError.notConfigured("torrentAdd")
            },
            torrentStart: { _ in
                throw TransmissionClientDependencyError.notConfigured("torrentStart")
            },
            torrentStop: { _ in throw TransmissionClientDependencyError.notConfigured("torrentStop")
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

    extension TransmissionClientDependency: DependencyKey {
        static let liveValue: Self = placeholder
        static let testValue: Self = placeholder
    }

    extension TransmissionClientDependency {
        static func live(client: TransmissionClientProtocol) -> Self {
            Self(
                sessionGet: { try await client.sessionGet() },
                sessionSet: { arguments in try await client.sessionSet(arguments: arguments) },
                sessionStats: { try await client.sessionStats() },
                torrentGet: { ids, fields in try await client.torrentGet(ids: ids, fields: fields)
                },
                torrentAdd: { filename, metainfo, downloadDir, paused, labels in
                    try await client.torrentAdd(
                        filename: filename,
                        metainfo: metainfo,
                        downloadDir: downloadDir,
                        paused: paused,
                        labels: labels
                    )
                },
                torrentStart: { ids in try await client.torrentStart(ids: ids) },
                torrentStop: { ids in try await client.torrentStop(ids: ids) },
                torrentRemove: { ids, deleteLocalData in
                    try await client.torrentRemove(ids: ids, deleteLocalData: deleteLocalData)
                },
                torrentSet: { ids, arguments in
                    try await client.torrentSet(ids: ids, arguments: arguments)
                },
                torrentVerify: { ids in try await client.torrentVerify(ids: ids) },
                checkServerVersion: { try await client.checkServerVersion() }
            )
        }
    }

    extension DependencyValues {
        @preconcurrency var transmissionClient: TransmissionClientDependency {
            get { self[TransmissionClientDependency.self] }
            set { self[TransmissionClientDependency.self] = newValue }
        }
    }
#endif
