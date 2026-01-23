import ComposableArchitecture
import Dependencies
import Foundation

extension TorrentListReducer {
    enum TorrentCommand: Equatable {
        case start
        case pause
        case verify
        case remove(deleteData: Bool)
    }

    func performCommand(
        _ command: TorrentCommand,
        torrentID: Torrent.Identifier,
        state: inout State
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            return .send(
                .errorPresenter(
                    .showAlert(
                        title: L10n.tr("torrentAdd.alert.noConnection.title"),
                        message: L10n.tr("torrentAdd.alert.noConnection.message"),
                        retry: nil
                    )
                )
            )
        }

        let initialStatus = state.items[id: torrentID]?.torrent.status ?? .stopped
        state.inFlightCommands[torrentID] = .init(
            command: command,
            initialStatus: initialStatus
        )

        return .run { send in
            do {
                try await environment.withDependencies {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    switch command {
                    case .start:
                        try await repository.start([torrentID])
                    case .pause:
                        try await repository.stop([torrentID])
                    case .verify:
                        try await repository.verify([torrentID])
                    case .remove(let deleteData):
                        try await repository.remove(
                            [torrentID],
                            deleteLocalData: deleteData
                        )
                    }
                }
                await send(.commandResponse(torrentID, .success(true)))
            } catch {
                await send(.commandResponse(torrentID, .failure(.init(message: error.userFacingMessage))))
            }
        }
        .cancellable(id: CancelID.command(torrentID), cancelInFlight: true)
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Выполняет запрос списка торрентов с учётом выбранного триггера (initial/manual/polling).
    func fetchTorrents(
        state: inout State,
        trigger: FetchTrigger
    ) -> Effect<Action> {
        let shouldFetchStorage: Bool = {
            switch trigger {
            case .initial, .manualRefresh, .polling, .command:
                return true
            case .preferencesChanged:
                return false
            }
        }()
        if state.serverID == nil {
            state.serverID = state.connectionEnvironment?.serverID ?? state.cacheKey?.serverID
        }

        switch trigger {
        case .initial:
            if state.items.isEmpty {
                state.phase = .loading
            }
        case .manualRefresh:
            state.isRefreshing = true
        case .polling:
            break
        case .preferencesChanged:
            break
        case .command:
            state.isRefreshing = false
        }

        state.errorPresenter.banner = nil

        guard let environment = state.connectionEnvironment else {
            state.isRefreshing = false
            guard let cacheKey = state.cacheKey else { return .none }

            return .run { send in
                let client = offlineCacheRepository.client(cacheKey)
                guard let snapshot = try await client.load() else { return }
                guard let cached = snapshot.torrents else { return }

                if shouldFetchStorage {
                    let summary = StorageSummary.calculate(
                        torrents: cached.value,
                        session: snapshot.session?.value,
                        updatedAt: snapshot.latestUpdatedAt
                    )
                    await send(.storageUpdated(summary))
                }

                await send(
                    .torrentsResponse(
                        .success(
                            State.FetchSuccess(
                                torrents: cached.value,
                                isFromCache: true,
                                snapshotDate: cached.updatedAt
                            )
                        )
                    )
                )
                await send(
                    .torrentsResponse(.failure(TorrentListOfflineError.connectionUnavailable))
                )
            }
            .cancellable(id: CancelID.fetch, cancelInFlight: true)
        }

        return .run { send in
            do {
                let torrents = try await environment.withDependencies {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    return try await repository.fetchList()
                }
                let session =
                    shouldFetchStorage
                    ? (try? await environment.withDependencies {
                        @Dependency(\.sessionRepository) var sessionRepository: SessionRepository
                        return try await sessionRepository.fetchState()
                    })
                    : nil
                if let session {
                    await applySeedRatioPolicy(
                        torrents: torrents,
                        session: session,
                        environment: environment
                    )
                }
                let snapshot = (try? await environment.snapshot.load()) ?? nil
                let updatedAt = snapshot?.torrents?.updatedAt
                if shouldFetchStorage {
                    let summary = StorageSummary.calculate(
                        torrents: torrents,
                        session: session,
                        updatedAt: updatedAt
                    )
                    await send(.storageUpdated(summary))
                }
                await send(
                    .torrentsResponse(
                        .success(
                            State.FetchSuccess(
                                torrents: torrents,
                                isFromCache: false,
                                snapshotDate: updatedAt
                            )
                        )
                    )
                )
            } catch {
                if let snapshot = try? await environment.snapshot.load() {
                    if let cached = snapshot.torrents {
                        if shouldFetchStorage {
                            let summary = StorageSummary.calculate(
                                torrents: cached.value,
                                session: snapshot.session?.value,
                                updatedAt: snapshot.latestUpdatedAt
                            )
                            await send(.storageUpdated(summary))
                        }
                        await send(
                            .torrentsResponse(
                                .success(
                                    State.FetchSuccess(
                                        torrents: cached.value,
                                        isFromCache: true,
                                        snapshotDate: cached.updatedAt
                                    )
                                )
                            )
                        )
                    }
                }
                await send(.torrentsResponse(.failure(error)))
            }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    private func applySeedRatioPolicy(
        torrents: [Torrent],
        session: SessionState,
        environment: ServerConnectionEnvironment
    ) async {
        guard session.seedRatioLimit.isEnabled else { return }
        let limit = session.seedRatioLimit.value
        let stopIDs = torrents.compactMap { torrent -> Torrent.Identifier? in
            guard torrent.status == .seeding else { return nil }
            return torrent.summary.progress.uploadRatio > limit ? torrent.id : nil
        }
        let startIDs = torrents.compactMap { torrent -> Torrent.Identifier? in
            guard torrent.summary.progress.percentDone >= 1 else { return nil }
            guard torrent.summary.progress.uploadRatio < limit else { return nil }
            guard torrent.status == .stopped || torrent.status == .seedWaiting else {
                return nil
            }
            return torrent.id
        }
        guard stopIDs.isEmpty == false || startIDs.isEmpty == false else { return }
        do {
            try await environment.withDependencies {
                @Dependency(\.torrentRepository) var repository: TorrentRepository
                if stopIDs.isEmpty == false {
                    try await repository.stop(stopIDs)
                }
                if startIDs.isEmpty == false {
                    try await repository.start(startIDs)
                }
            }
        } catch {
            return
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length
}
