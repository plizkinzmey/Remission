import ComposableArchitecture
import Foundation

// MARK: - Helper types

extension TorrentListReducer {
    enum FetchTrigger {
        case initial
        case manualRefresh
        case polling
        case preferencesChanged
        case command
    }

    enum TorrentListOfflineError: Error, LocalizedError {
        case connectionUnavailable

        var errorDescription: String? {
            L10n.tr("torrentList.state.noConnection.message")
        }
    }
}

// MARK: - Helper methods

extension TorrentListReducer {
    func loadPreferences() -> Effect<Action> {
        .run { send in
            await send(
                .userPreferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load()
                    }
                )
            )
        }
        .cancellable(id: CancelID.preferences, cancelInFlight: true)
    }

    func observePreferences() -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe()
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.preferencesUpdates, cancelInFlight: true)
    }

    func loadCachedSnapshot(cacheKey: OfflineCacheKey) -> Effect<Action> {
        .run { send in
            let client = offlineCacheRepository.client(cacheKey)
            guard let snapshot = try await client.load(),
                let cached = snapshot.torrents
            else { return }
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
        .cancellable(id: CancelID.cache, cancelInFlight: true)
    }

    func restartPolling(state: inout State) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.polling),
            fetchTorrents(state: &state, trigger: .preferencesChanged)
        )
    }

    func handleDetailUpdated(
        state: inout State,
        torrent: Torrent
    ) -> Effect<Action> {
        if var existing = state.items[id: torrent.id] {
            existing.update(with: torrent)
            state.items[id: torrent.id] = existing
        } else {
            state.items.append(TorrentListItem.State(torrent: torrent))
        }
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false
        return detailSyncEffect(state: &state)
    }

    func handleTorrentAdded(
        state: inout State,
        result: TorrentRepository.AddResult
    ) -> Effect<Action> {
        guard state.connectionEnvironment != nil else {
            return .none
        }
        if state.items[id: result.id] == nil {
            let placeholder = makePlaceholderTorrent(addResult: result)
            state.items.append(TorrentListItem.State(torrent: placeholder))
        }
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false

        let fetchEffect = fetchTorrents(state: &state, trigger: .command)
        return .merge(
            .cancel(id: CancelID.polling),
            fetchEffect
        )
    }

    func handleDetailRemoved(
        state: inout State,
        identifier: Torrent.Identifier
    ) -> Effect<Action> {
        state.items.remove(id: identifier)
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false
        return detailSyncEffect(state: &state)
    }

    func detailSyncEffect(state: inout State) -> Effect<Action> {
        guard state.connectionEnvironment != nil else {
            return .none
        }
        let fetchEffect = fetchTorrents(state: &state, trigger: .command)
        return .merge(
            .cancel(id: CancelID.polling),
            fetchEffect
        )
    }

    func schedulePolling(after delay: Duration) -> Effect<Action> {
        .run { send in
            let clock = appClock.clock()
            do {
                try await clock.sleep(for: delay)
                await send(.pollingTick)
            } catch is CancellationError {
                return
            }
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }

    func merge(
        items: IdentifiedArrayOf<TorrentListItem.State>,
        with torrents: [Torrent]
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        var updated: IdentifiedArrayOf<TorrentListItem.State> = []
        updated.reserveCapacity(torrents.count)

        for torrent in torrents {
            if var existing = items[id: torrent.id] {
                existing.update(with: torrent)
                updated.append(existing)
            } else {
                updated.append(TorrentListItem.State(torrent: torrent))
            }
        }

        return updated
    }

    func makePlaceholderTorrent(
        addResult: TorrentRepository.AddResult
    ) -> Torrent {
        let zeroLimits = Torrent.Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0)
        let summary = Torrent.Summary(
            progress: .init(
                percentDone: 0,
                totalSize: 0,
                downloadedEver: 0,
                uploadedEver: 0,
                uploadRatio: 0,
                etaSeconds: -1
            ),
            transfer: .init(
                downloadRate: 0,
                uploadRate: 0,
                downloadLimit: zeroLimits,
                uploadLimit: zeroLimits
            ),
            peers: .init(connected: 0, sources: [])
        )
        return Torrent(
            id: addResult.id,
            name: addResult.name,
            status: .downloadWaiting,
            summary: summary
        )
    }

    func backoffDelay(for failures: Int) -> Duration {
        guard failures > 0 else { return .seconds(1) }
        let values: [Duration] = [
            .seconds(1),
            .seconds(2),
            .seconds(4),
            .seconds(8),
            .seconds(16),
            .seconds(30)
        ]
        let index = min(failures - 1, values.count - 1)
        return values[index]
    }

    var maxRetryAttempts: Int { 5 }

    func duration(from interval: TimeInterval) -> Duration {
        .milliseconds(Int(interval * 1_000))
    }

    func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError {
            if let description = localized.errorDescription, description.isEmpty == false {
                return description
            }
        }
        return String(describing: error)
    }
}
