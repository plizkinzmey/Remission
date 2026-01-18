import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Контракт доступа к Torrent доменному слою.
protocol TorrentRepositoryProtocol: Sendable {
    func fetchList() async throws -> [Torrent]
    func fetchDetails(_ id: Torrent.Identifier) async throws -> Torrent
    func add(
        _ input: PendingTorrentInput,
        destinationPath: String,
        startPaused: Bool,
        tags: [String]?
    ) async throws -> TorrentRepository.AddResult
    func start(_ ids: [Torrent.Identifier]) async throws
    func stop(_ ids: [Torrent.Identifier]) async throws
    func remove(_ ids: [Torrent.Identifier], deleteLocalData: Bool?) async throws
    func verify(_ ids: [Torrent.Identifier]) async throws
    func updateTransferSettings(
        _ settings: TorrentRepository.TransferSettings,
        for ids: [Torrent.Identifier]
    ) async throws
    func updateLabels(_ labels: [String], for ids: [Torrent.Identifier]) async throws
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

    enum AddStatus: Equatable, Sendable {
        case added
        case duplicate
    }

    struct AddResult: Equatable, Sendable {
        var status: AddStatus
        var id: Torrent.Identifier
        var name: String
        var hashString: String
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
    var addClosure:
        @Sendable (PendingTorrentInput, String, Bool, [String]?) async throws -> AddResult
    var startClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var stopClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var removeClosure: @Sendable ([Torrent.Identifier], Bool?) async throws -> Void
    var verifyClosure: @Sendable ([Torrent.Identifier]) async throws -> Void
    var updateTransferSettingsClosure:
        @Sendable (TransferSettings, [Torrent.Identifier]) async throws -> Void
    var updateLabelsClosure: @Sendable ([String], [Torrent.Identifier]) async throws -> Void
    var updateFileSelectionClosure:
        @Sendable ([FileSelectionUpdate], Torrent.Identifier) async throws -> Void
    var cacheListClosure: @Sendable ([Torrent]) async throws -> Void
    var loadCachedListClosure: @Sendable () async throws -> CachedSnapshot<[Torrent]>?

    init(
        fetchList: @escaping @Sendable () async throws -> [Torrent],
        fetchDetails: @escaping @Sendable (Torrent.Identifier) async throws -> Torrent,
        add:
            @escaping @Sendable (
                PendingTorrentInput, String, Bool, [String]?
            ) async throws -> AddResult,
        start: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        stop: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        remove: @escaping @Sendable ([Torrent.Identifier], Bool?) async throws -> Void,
        verify: @escaping @Sendable ([Torrent.Identifier]) async throws -> Void,
        updateTransferSettings:
            @escaping @Sendable (TransferSettings, [Torrent.Identifier])
            async throws -> Void,
        updateLabels: @escaping @Sendable ([String], [Torrent.Identifier]) async throws -> Void,
        updateFileSelection:
            @escaping @Sendable ([FileSelectionUpdate], Torrent.Identifier)
            async throws -> Void,
        cacheList: @escaping @Sendable ([Torrent]) async throws -> Void = { _ in },
        loadCachedList: @escaping @Sendable () async throws -> CachedSnapshot<[Torrent]>? = { nil }
    ) {
        self.fetchListClosure = fetchList
        self.fetchDetailsClosure = fetchDetails
        self.addClosure = add
        self.startClosure = start
        self.stopClosure = stop
        self.removeClosure = remove
        self.verifyClosure = verify
        self.updateTransferSettingsClosure = updateTransferSettings
        self.updateLabelsClosure = updateLabels
        self.updateFileSelectionClosure = updateFileSelection
        self.cacheListClosure = cacheList
        self.loadCachedListClosure = loadCachedList
    }

    func fetchList() async throws -> [Torrent] {
        try await fetchListClosure()
    }

    func fetchDetails(_ id: Torrent.Identifier) async throws -> Torrent {
        try await fetchDetailsClosure(id)
    }

    func add(
        _ input: PendingTorrentInput,
        destinationPath: String,
        startPaused: Bool,
        tags: [String]?
    ) async throws -> AddResult {
        try await addClosure(input, destinationPath, startPaused, tags)
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

    func updateLabels(_ labels: [String], for ids: [Torrent.Identifier]) async throws {
        try await updateLabelsClosure(labels, ids)
    }

    func updateFileSelection(
        _ updates: [FileSelectionUpdate],
        in torrentID: Torrent.Identifier
    ) async throws {
        try await updateFileSelectionClosure(updates, torrentID)
    }

    func cacheList(_ torrents: [Torrent]) async throws {
        try await cacheListClosure(torrents)
    }

    func loadCachedList() async throws -> CachedSnapshot<[Torrent]>? {
        try await loadCachedListClosure()
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
        // swiftlint:disable function_body_length
        static func live(
            transmissionClient: TransmissionClientDependency,
            mapper: TransmissionDomainMapper = TransmissionDomainMapper(),
            fields: [String] = TorrentListFields.summary,
            detailFields: [String] = TorrentListFields.details,
            snapshot: OfflineCacheClient? = nil
        ) -> TorrentRepository {
            let cacheList: @Sendable ([Torrent]) async throws -> Void = { torrents in
                guard let snapshot else { return }
                do {
                    _ = try await snapshot.updateTorrents(torrents)
                } catch OfflineCacheError.exceedsSizeLimit {
                    try await snapshot.clear()
                }
            }

            let loadCachedList: @Sendable () async throws -> CachedSnapshot<[Torrent]>? = {
                guard let snapshot else { return nil }
                return try await snapshot.load()?.torrents
            }

            let fetchList: @Sendable () async throws -> [Torrent] = {
                let response = try await transmissionClient.torrentGet(nil, fields)
                let torrents = try mapper.mapTorrentList(from: response)
                try await cacheList(torrents)
                return torrents
            }

            let fetchDetails: @Sendable (Torrent.Identifier) async throws -> Torrent =
                { identifier in
                    let response = try await transmissionClient.torrentGet(
                        [identifier.rawValue],
                        detailFields
                    )
                    return try mapper.mapTorrentDetails(from: response)
                }

            let add:
                @Sendable (PendingTorrentInput, String, Bool, [String]?) async throws
                    -> AddResult =
                    { input, destination, startPaused, labels in
                        let response = try await transmissionClient.torrentAdd(
                            filename: input.filenameArgument,
                            metainfo: input.metainfoArgument,
                            downloadDir: destination,
                            paused: startPaused,
                            labels: labels
                        )
                        return try mapper.mapTorrentAdd(from: response)
                    }

            let start: @Sendable ([Torrent.Identifier]) async throws -> Void = makeCommandClosure(
                context: "torrent-start",
                rpc: transmissionClient.torrentStart
            )

            let stop: @Sendable ([Torrent.Identifier]) async throws -> Void = makeCommandClosure(
                context: "torrent-stop",
                rpc: transmissionClient.torrentStop
            )

            let remove: @Sendable ([Torrent.Identifier], Bool?) async throws -> Void =
                { ids, deleteData in
                    let response = try await transmissionClient.torrentRemove(
                        ids.map(\.rawValue),
                        deleteData
                    )
                    try ensureSuccess(response, context: "torrent-remove")
                }

            let verify: @Sendable ([Torrent.Identifier]) async throws -> Void = makeCommandClosure(
                context: "torrent-verify",
                rpc: transmissionClient.torrentVerify
            )

            let updateTransferSettings:
                @Sendable (TransferSettings, [Torrent.Identifier]) async throws
                    -> Void = { settings, ids in
                        let arguments = makeTransferSettingsArguments(from: settings)
                        guard arguments.isEmpty == false else {
                            return
                        }
                        let response = try await transmissionClient.torrentSet(
                            ids.map(\.rawValue),
                            .object(arguments)
                        )
                        try ensureSuccess(response, context: "torrent-set")
                    }

            let updateLabels: @Sendable ([String], [Torrent.Identifier]) async throws -> Void =
                { labels, ids in
                    guard labels.isEmpty == false else { return }
                    let arguments: [String: AnyCodable] = [
                        "labels": .array(labels.map { .string($0) })
                    ]
                    let response = try await transmissionClient.torrentSet(
                        ids.map(\.rawValue),
                        .object(arguments)
                    )
                    try ensureSuccess(response, context: "torrent-set")
                }

            let updateFileSelection:
                @Sendable ([FileSelectionUpdate], Torrent.Identifier) async throws
                    -> Void = { updates, torrentID in
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

            return TorrentRepository(
                fetchList: fetchList,
                fetchDetails: fetchDetails,
                add: add,
                start: start,
                stop: stop,
                remove: remove,
                verify: verify,
                updateTransferSettings: updateTransferSettings,
                updateLabels: updateLabels,
                updateFileSelection: updateFileSelection,
                cacheList: cacheList,
                loadCachedList: loadCachedList
            )
        }
        // swiftlint:enable function_body_length

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
            var priorityBuckets: [FilePriority: Set<Int>] = [
                .high: [],
                .normal: [],
                .low: []
            ]

            for update in updates {
                if let isWanted = update.isWanted {
                    var target = isWanted ? filesWanted : filesUnwanted
                    target.insert(update.fileIndex)
                    if isWanted {
                        filesWanted = target
                    } else {
                        filesUnwanted = target
                    }
                }

                if let priority = update.priority {
                    priorityBuckets[priority, default: []].insert(update.fileIndex)
                }
            }

            var arguments: [String: AnyCodable] = [:]
            appendArrayArgument(from: filesWanted, forKey: "files-wanted", into: &arguments)
            appendArrayArgument(from: filesUnwanted, forKey: "files-unwanted", into: &arguments)
            appendArrayArgument(
                from: priorityBuckets[.high] ?? [], forKey: "priority-high", into: &arguments)
            appendArrayArgument(
                from: priorityBuckets[.normal] ?? [],
                forKey: "priority-normal",
                into: &arguments
            )
            appendArrayArgument(
                from: priorityBuckets[.low] ?? [], forKey: "priority-low", into: &arguments)
            return arguments
        }

        private static func arrayArgument(from indices: Set<Int>) -> AnyCodable? {
            guard indices.isEmpty == false else {
                return nil
            }
            let values = indices.sorted().map { AnyCodable.int($0) }
            return .array(values)
        }

        private static func appendArrayArgument(
            from indices: Set<Int>,
            forKey key: String,
            into arguments: inout [String: AnyCodable]
        ) {
            guard let value = arrayArgument(from: indices) else { return }
            arguments[key] = value
        }
    }
#endif

extension PendingTorrentInput {
    fileprivate var filenameArgument: String? {
        switch payload {
        case .magnetLink(_, let rawValue):
            return rawValue
        case .torrentFile:
            return nil
        }
    }

    fileprivate var metainfoArgument: Data? {
        switch payload {
        case .torrentFile(let data, _):
            return data
        case .magnetLink:
            return nil
        }
    }
}

extension TorrentRepository {
    static let placeholder: TorrentRepository = TorrentRepository(
        fetchList: { [] },
        fetchDetails: { _ in
            throw TorrentRepositoryError.notConfigured("fetchDetails")
        },
        add: { _, _, _, _ in
            throw TorrentRepositoryError.notConfigured("add")
        },
        start: { _ in },
        stop: { _ in },
        remove: { _, _ in },
        verify: { _ in },
        updateTransferSettings: { _, _ in },
        updateLabels: { _, _ in },
        updateFileSelection: { _, _ in }
    )

    static let unimplemented: TorrentRepository = TorrentRepository(
        fetchList: {
            throw TorrentRepositoryError.notConfigured("fetchList")
        },
        fetchDetails: { _ in
            throw TorrentRepositoryError.notConfigured("fetchDetails")
        },
        add: { _, _, _, _ in
            throw TorrentRepositoryError.notConfigured("add")
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
        updateLabels: { _, _ in
            throw TorrentRepositoryError.notConfigured("updateLabels")
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
