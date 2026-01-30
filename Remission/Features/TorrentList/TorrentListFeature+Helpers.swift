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
    func loadPreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            await send(
                .userPreferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
        .cancellable(id: CancelID.preferences, cancelInFlight: true)
    }

    func observePreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe(serverID: serverID)
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.preferencesUpdates, cancelInFlight: true)
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
            existing.isRemoving = state.removingTorrentIDs.contains(torrent.id)
            state.items[id: torrent.id] = existing
        } else {
            let isRemoving = state.removingTorrentIDs.contains(torrent.id)
            state.items.append(TorrentListItem.State(torrent: torrent, isRemoving: isRemoving))
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
        state.removingTorrentIDs.remove(identifier)
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
        with torrents: [Torrent],
        removingIDs: Set<Torrent.Identifier>
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        var updated = items

        // Удаляем те, которых больше нет в ответе сервера
        let newIDs = Set(torrents.map(\.id))
        updated.removeAll(where: { !newIDs.contains($0.id) })

        // Обновляем существующие или добавляем новые
        for torrent in torrents {
            let isRemoving = removingIDs.contains(torrent.id)
            if var existing = updated[id: torrent.id] {
                existing.update(with: torrent)
                existing.isRemoving = isRemoving
                updated[id: torrent.id] = existing
            } else {
                updated.append(TorrentListItem.State(torrent: torrent, isRemoving: isRemoving))
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
                recheckProgress: 0.0,
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
        BackoffStrategy.delay(for: failures)
    }

    var maxRetryAttempts: Int { 3 }

    func duration(from interval: TimeInterval) -> Duration {
        .milliseconds(Int(interval * 1_000))
    }

    func describe(_ error: Error) -> String {
        error.userFacingMessage
    }
}
