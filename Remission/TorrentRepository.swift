import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Контракт доступа к Torrent доменному слою.
protocol TorrentRepositoryProtocol: Sendable {
    func fetchList() async throws -> [Torrent]
    func fetchDetails(_ id: Torrent.Identifier) async throws -> Torrent
    func start(_ ids: [Torrent.Identifier]) async throws
    func stop(_ ids: [Torrent.Identifier]) async throws
    func remove(_ ids: [Torrent.Identifier], deleteLocalData: Bool?) async throws
    func verify(_ ids: [Torrent.Identifier]) async throws
    func updateTransferSettings(
        _ settings: TorrentRepository.TransferSettings,
        for ids: [Torrent.Identifier]
    ) async throws
    func updateFileSelection(
        _ updates: [TorrentRepository.FileSelectionUpdate],
        in torrentID: Torrent.Identifier
    ) async throws
}

/// Обёртка, совместимая с `DependencyKey`, предоставляющая closure-based API.
struct TorrentRepository: Sendable, TorrentRepositoryProtocol {
    struct TransferLimit: Equatable, Sendable {
        var isEnabled: Bool
        var kilobytesPerSecond: Int

        public init(isEnabled: Bool, kilobytesPerSecond: Int) {
            self.isEnabled = isEnabled
            self.kilobytesPerSecond = kilobytesPerSecond
        }
    }

    struct TransferSettings: Equatable, Sendable {
        /// Лимит скачивания. `nil` — не изменять.
        var downloadLimit: TransferLimit?
        /// Лимит отдачи. `nil` — не изменять.
        var uploadLimit: TransferLimit?

        public init(
            downloadLimit: TransferLimit? = nil,
            uploadLimit: TransferLimit? = nil
        ) {
            self.downloadLimit = downloadLimit
            self.uploadLimit = uploadLimit
        }
    }

    enum FilePriority: Int, Equatable, Sendable {
        case low = -1
        case normal = 0
        case high = 1
    }

    struct FileSelectionUpdate: Equatable, Sendable {
        /// Индекс файла из `Torrent.Details.files`.
        var fileIndex: Int
        /// Обновлённое значение wanted-флага. `nil` — оставить без изменений.
        var isWanted: Bool?
        /// Обновлённый приоритет. `nil` — оставить без изменений.
        var priority: FilePriority?

        public init(fileIndex: Int, isWanted: Bool? = nil, priority: FilePriority? = nil) {
            self.fileIndex = fileIndex
            self.isWanted = isWanted
            self.priority = priority
        }
    }

    var fetchListClosure: @Sendable () async throws -> [Torrent]
    var fetchDetailsClosure: @Sendable (Torrent.Identifier) async throws -> Torrent
    var startClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var stopClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var removeClosure: @Sendable ([Torrent.Identifier], Bool?) async throws -> Void
    var verifyClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var updateTransferSettingsClosure:
        @Sendable (TransferSettings, [Torrent.Identifier]) async throws -> Void
    var updateFileSelectionClosure:
        @Sendable ([FileSelectionUpdate], Torrent.Identifier) async throws -> Void

    init(
        fetchList: @escaping @Sendable () async throws -> [Torrent],
        fetchDetails: @escaping @Sendable (Torrent.Identifier) async throws -> Torrent,
        start: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        stop: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        remove: @escaping @Sendable ([Torrent.Identifier], Bool?) async throws -> Void,
        verify: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        updateTransferSettings:
            @escaping @Sendable (TransferSettings, [Torrent.Identifier])
            async throws -> Void,
        updateFileSelection:
            @escaping @Sendable ([FileSelectionUpdate], Torrent.Identifier)
            async throws -> Void
    ) {
        self.fetchListClosure = fetchList
        self.fetchDetailsClosure = fetchDetails
        self.startClosure = start
        self.stopClosure = stop
        self.removeClosure = remove
        self.verifyClosure = verify
        self.updateTransferSettingsClosure = updateTransferSettings
        self.updateFileSelectionClosure = updateFileSelection
    }

    func fetchList() async throws -> [Torrent] {
        try await fetchListClosure()
    }

    func fetchDetails(_ id: Torrent.Identifier) async throws -> Torrent {
        try await fetchDetailsClosure(id)
    }

    func start(_ ids: [Torrent.Identifier]) async throws {
        try await startClosure(ids)
    }

    func stop(_ ids: [Torrent.Identifier]) async throws {
        try await stopClosure(ids)
    }

    func remove(_ ids: [Torrent.Identifier], deleteLocalData: Bool?) async throws {
        try await removeClosure(ids, deleteLocalData)
    }

    func verify(_ ids: [Torrent.Identifier]) async throws {
        try await verifyClosure(ids)
    }

    func updateTransferSettings(
        _ settings: TransferSettings,
        for ids: [Torrent.Identifier]
    ) async throws {
        try await updateTransferSettingsClosure(settings, ids)
    }

    func updateFileSelection(
        _ updates: [FileSelectionUpdate],
        in torrentID: Torrent.Identifier
    ) async throws {
        try await updateFileSelectionClosure(updates, torrentID)
    }
}

#if canImport(ComposableArchitecture)
    extension TorrentRepository: DependencyKey {
        static var liveValue: TorrentRepository {
            @Dependency(\.transmissionClient) var transmissionClient
            return .live(transmissionClient: transmissionClient)
        }
        static var previewValue: TorrentRepository {
            .inMemory(
                store: InMemoryTorrentRepositoryStore(
                    torrents: [
                        .previewDownloading,
                        .previewCompleted
                    ]
                )
            )
        }
        static var testValue: TorrentRepository {
            .inMemory(store: InMemoryTorrentRepositoryStore())
        }
    }

    extension DependencyValues {
        var torrentRepository: TorrentRepository {
            get { self[TorrentRepository.self] }
            set { self[TorrentRepository.self] = newValue }
        }
    }

    extension TorrentRepository {
        static func live(
            transmissionClient: TransmissionClientDependency,
            mapper: TransmissionDomainMapper = TransmissionDomainMapper(),
            fields: [String] = TorrentListFields.summary,
            detailFields: [String] = TorrentListFields.details
        ) -> TorrentRepository {
            TorrentRepository(
                fetchList: {
                    let response = try await transmissionClient.torrentGet(nil, fields)
                    return try mapper.mapTorrentList(from: response)
                },
                fetchDetails: { identifier in
                    let response = try await transmissionClient.torrentGet(
                        [identifier.rawValue],
                        detailFields
                    )
                    return try mapper.mapTorrentDetails(from: response)
                },
                start: makeCommandClosure(
                    context: "torrent-start",
                    rpc: transmissionClient.torrentStart
                ),
                stop: makeCommandClosure(
                    context: "torrent-stop",
                    rpc: transmissionClient.torrentStop
                ),
                remove: { ids, deleteData in
                    let response = try await transmissionClient.torrentRemove(
                        ids.map(\.rawValue),
                        deleteData
                    )
                    try ensureSuccess(response, context: "torrent-remove")
                },
                verify: makeCommandClosure(
                    context: "torrent-verify",
                    rpc: transmissionClient.torrentVerify
                ),
                updateTransferSettings: { settings, ids in
                    let arguments = makeTransferSettingsArguments(from: settings)
                    guard arguments.isEmpty == false else {
                        return
                    }
                    let response = try await transmissionClient.torrentSet(
                        ids.map(\.rawValue),
                        .object(arguments)
                    )
                    try ensureSuccess(response, context: "torrent-set")
                },
                updateFileSelection: { updates, torrentID in
                    let arguments = makeFileSelectionArguments(from: updates)
                    guard arguments.isEmpty == false else {
                        return
                    }
                    let response = try await transmissionClient.torrentSet(
                        [torrentID.rawValue],
                        .object(arguments)
                    )
                    try ensureSuccess(response, context: "torrent-set")
                }
            )
        }

        private static func makeCommandClosure(
            context: String,
            rpc: @escaping @Sendable ([Int]) async throws -> TransmissionResponse
        ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
            { ids in
                let response = try await rpc(ids.map(\.rawValue))
                try ensureSuccess(response, context: context)
            }
        }

        private static func ensureSuccess(
            _ response: TransmissionResponse,
            context: String
        ) throws {
            guard response.isSuccess else {
                throw DomainMappingError.rpcError(result: response.result, context: context)
            }
        }

        private static func makeTransferSettingsArguments(
            from settings: TransferSettings
        ) -> [String: AnyCodable] {
            var arguments: [String: AnyCodable] = [:]

            if let downloadLimit = settings.downloadLimit {
                arguments["downloadLimit"] = .int(downloadLimit.kilobytesPerSecond)
                arguments["downloadLimited"] = .bool(downloadLimit.isEnabled)
            }

            if let uploadLimit = settings.uploadLimit {
                arguments["uploadLimit"] = .int(uploadLimit.kilobytesPerSecond)
                arguments["uploadLimited"] = .bool(uploadLimit.isEnabled)
            }

            return arguments
        }

        private static func makeFileSelectionArguments(
            from updates: [FileSelectionUpdate]
        ) -> [String: AnyCodable] {
            var filesWanted: Set<Int> = []
            var filesUnwanted: Set<Int> = []
            var priorityHigh: Set<Int> = []
            var priorityNormal: Set<Int> = []
            var priorityLow: Set<Int> = []

            for update in updates {
                if let isWanted = update.isWanted {
                    if isWanted {
                        filesWanted.insert(update.fileIndex)
                    } else {
                        filesUnwanted.insert(update.fileIndex)
                    }
                }

                if let priority = update.priority {
                    switch priority {
                    case .high:
                        priorityHigh.insert(update.fileIndex)
                    case .normal:
                        priorityNormal.insert(update.fileIndex)
                    case .low:
                        priorityLow.insert(update.fileIndex)
                    }
                }
            }

            var arguments: [String: AnyCodable] = [:]
            if let value = arrayArgument(from: filesWanted) {
                arguments["files-wanted"] = value
            }
            if let value = arrayArgument(from: filesUnwanted) {
                arguments["files-unwanted"] = value
            }
            if let value = arrayArgument(from: priorityHigh) {
                arguments["priority-high"] = value
            }
            if let value = arrayArgument(from: priorityNormal) {
                arguments["priority-normal"] = value
            }
            if let value = arrayArgument(from: priorityLow) {
                arguments["priority-low"] = value
            }

            return arguments
        }

        private static func arrayArgument(from indices: Set<Int>) -> AnyCodable? {
            guard indices.isEmpty == false else {
                return nil
            }
            let values = indices.sorted().map { AnyCodable.int($0) }
            return .array(values)
        }
    }
#endif

extension TorrentRepository {
    static let placeholder: TorrentRepository = TorrentRepository(
        fetchList: { [] },
        fetchDetails: { _ in
            throw TorrentRepositoryError.notConfigured("fetchDetails")
        },
        start: { _ in },
        stop: { _ in },
        remove: { _, _ in },
        verify: { _ in },
        updateTransferSettings: { _, _ in },
        updateFileSelection: { _, _ in }
    )

    static let unimplemented: TorrentRepository = TorrentRepository(
        fetchList: {
            throw TorrentRepositoryError.notConfigured("fetchList")
        },
        fetchDetails: { _ in
            throw TorrentRepositoryError.notConfigured("fetchDetails")
        },
        start: { _ in
            throw TorrentRepositoryError.notConfigured("start")
        },
        stop: { _ in
            throw TorrentRepositoryError.notConfigured("stop")
        },
        remove: { _, _ in
            throw TorrentRepositoryError.notConfigured("remove")
        },
        verify: { _ in
            throw TorrentRepositoryError.notConfigured("verify")
        },
        updateTransferSettings: { _, _ in
            throw TorrentRepositoryError.notConfigured("updateTransferSettings")
        },
        updateFileSelection: { _, _ in
            throw TorrentRepositoryError.notConfigured("updateFileSelection")
        }
    )
}

private enum TorrentRepositoryError: Error, LocalizedError, Sendable {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let name):
            return "TorrentRepository.\(name) is not configured for this environment."
        }
    }
}
