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

        return .run { send in
            do {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
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
                await send(.commandResponse(.success(true)))
            } catch {
                let message =
                    (error as? APIError)?.userFriendlyMessage
                    ?? describe(error)
                await send(.commandResponse(.failure(.init(message: message))))
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
                let torrents = try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    return try await repository.fetchList()
                }
                let snapshot = (try? await environment.snapshot.load()) ?? nil
                let updatedAt = snapshot?.torrents?.updatedAt
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
    // swiftlint:enable cyclomatic_complexity function_body_length
}
