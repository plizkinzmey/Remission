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
        let shouldUpdateMetrics = shouldRefreshMetrics(state: &state)
        var didChange = false
        if var existing = state.items[id: torrent.id] {
            let isRemoving = state.removingTorrentIDs.contains(torrent.id)
            let didUpdate = existing.update(with: torrent, updateMetrics: shouldUpdateMetrics)
            let didUpdateRemoving = existing.isRemoving != isRemoving
            if didUpdateRemoving {
                existing.isRemoving = isRemoving
            }
            if didUpdate || didUpdateRemoving {
                state.items[id: torrent.id] = existing
                didChange = true
            }
        } else {
            let isRemoving = state.removingTorrentIDs.contains(torrent.id)
            state.items.append(TorrentListItem.State(torrent: torrent, isRemoving: isRemoving))
            didChange = true
        }
        if didChange {
            state.itemsRevision += 1
            updateVisibleItemsCache(state: &state)
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
        var didAdd = false
        if state.items[id: result.id] == nil {
            let placeholder = makePlaceholderTorrent(addResult: result)
            state.items.append(TorrentListItem.State(torrent: placeholder))
            didAdd = true
        }
        if didAdd {
            state.itemsRevision += 1
            updateVisibleItemsCache(state: &state)
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
        let didRemove = state.items.remove(id: identifier) != nil
        if didRemove {
            state.itemsRevision += 1
            updateVisibleItemsCache(state: &state)
        }
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

    func nextAdaptiveInterval(
        state: inout State,
        hasVisibleChanges: Bool
    ) -> Duration {
        guard state.isPollingEnabled else {
            state.adaptivePollingInterval = nil
            return state.pollingInterval
        }
        if hasVisibleChanges {
            state.adaptivePollingInterval = nil
            return state.pollingInterval
        }
        let base = state.pollingInterval
        let current = state.adaptivePollingInterval ?? base
        let next = min(current * 2, .seconds(30))
        state.adaptivePollingInterval = next
        return next
    }

    func merge(
        state: inout State,
        with torrents: [Torrent],
        removingIDs: Set<Torrent.Identifier>
    ) -> (items: IdentifiedArrayOf<TorrentListItem.State>, didChange: Bool) {
        var updated = state.items
        var didChange = false
        let shouldUpdateMetrics = shouldRefreshMetrics(state: &state)
        let sampleID = mergeSampleID(from: torrents)

        // Удаляем те, которых больше нет в ответе сервера
        let newIDs = Set(torrents.map(\.id))
        let beforeCount = updated.count
        updated.removeAll(where: { !newIDs.contains($0.id) })
        if updated.count != beforeCount {
            didChange = true
        }

        // Обновляем существующие или добавляем новые
        for torrent in torrents {
            let isRemoving = removingIDs.contains(torrent.id)
            if var existing = updated[id: torrent.id] {
                let didUpdate = existing.update(with: torrent, updateMetrics: shouldUpdateMetrics)
                logMergeSampleIfNeeded(
                    sampleID: sampleID,
                    torrent: torrent,
                    didUpdate: didUpdate,
                    updateMetrics: shouldUpdateMetrics,
                    existing: existing
                )
                let didUpdateRemoving = existing.isRemoving != isRemoving
                if didUpdateRemoving {
                    existing.isRemoving = isRemoving
                }
                if didUpdate || didUpdateRemoving {
                    updated[id: torrent.id] = existing
                    didChange = true
                }
            } else {
                updated.append(TorrentListItem.State(torrent: torrent, isRemoving: isRemoving))
                didChange = true
            }
        }

        return (updated, didChange)
    }

    func shouldRefreshMetrics(state: inout State) -> Bool {
        let now = dateProvider.now()
        guard let lastUpdate = state.lastMetricsUpdateAt else {
            state.lastMetricsUpdateAt = now
            state.metricsRevision += 1
            if appLogger.isNoop == false {
                appLogger.withCategory("torrent-list").debug(
                    "metrics.refresh.first",
                    metadata: ["metricsRevision": "\(state.metricsRevision)"]
                )
            }
            return true
        }
        let delta = now.timeIntervalSince(lastUpdate)
        if delta >= 1.0 {
            state.lastMetricsUpdateAt = now
            state.metricsRevision += 1
            if appLogger.isNoop == false {
                appLogger.withCategory("torrent-list").debug(
                    "metrics.refresh",
                    metadata: [
                        "delta": "\(String(format: "%.3f", delta))",
                        "metricsRevision": "\(state.metricsRevision)"
                    ]
                )
            }
            return true
        }
        if appLogger.isNoop == false {
            appLogger.withCategory("torrent-list").debug(
                "metrics.skip",
                metadata: [
                    "delta": "\(String(format: "%.3f", delta))",
                    "metricsRevision": "\(state.metricsRevision)"
                ]
            )
        }
        return false
    }

    func mergeSampleID(from torrents: [Torrent]) -> Torrent.Identifier? {
        guard appLogger.isNoop == false else { return nil }
        return torrents.first(where: { $0.status == .downloading })?.id ?? torrents.first?.id
    }

    func logMergeSampleIfNeeded(
        sampleID: Torrent.Identifier?,
        torrent: Torrent,
        didUpdate: Bool,
        updateMetrics: Bool,
        existing: TorrentListItem.State
    ) {
        guard appLogger.isNoop == false, sampleID == torrent.id else { return }
        let oldSignature = existing.displaySignature
        let newSignature = TorrentListItem.State.displaySignature(for: torrent)
        appLogger.withCategory("torrent-list").debug(
            "merge.sample",
            metadata: [
                "id": "\(torrent.id.rawValue)",
                "didUpdate": "\(didUpdate)",
                "updateMetrics": "\(updateMetrics)",
                "oldStatus": "\(oldSignature.status)",
                "newStatus": "\(newSignature.status)",
                "oldPercent": "\(oldSignature.percentDone)",
                "newPercent": "\(newSignature.percentDone)",
                "oldDown": "\(oldSignature.downloadRate)",
                "newDown": "\(newSignature.downloadRate)",
                "oldUp": "\(oldSignature.uploadRate)",
                "newUp": "\(newSignature.uploadRate)",
                "oldPeers": "\(oldSignature.peersConnected)",
                "newPeers": "\(newSignature.peersConnected)",
                "oldEta": "\(oldSignature.etaSeconds)",
                "newEta": "\(newSignature.etaSeconds)"
            ]
        )
    }

    func updateVisibleItemsCache(state: inout State) {
        let signature = TorrentListReducer.VisibleItemsSignature(
            query: state.normalizedSearchQuery,
            filter: state.selectedFilter,
            category: state.selectedCategory,
            itemsRevision: state.itemsRevision,
            metricsRevision: state.metricsRevision
        )
        guard state.visibleItemsSignature != signature else {
            if appLogger.isNoop == false {
                appLogger.withCategory("torrent-list").debug(
                    "visibleItemsCache.skip",
                    metadata: [
                        "visible": "\(state.visibleItemsCache.count)",
                        "itemsRevision": "\(state.itemsRevision)",
                        "metricsRevision": "\(state.metricsRevision)",
                        "filter": "\(state.selectedFilter.rawValue)",
                        "category": "\(state.selectedCategory.rawValue)",
                        "query": "\(state.normalizedSearchQuery)"
                    ]
                )
            }
            return
        }
        state.visibleItemsCache = state.filteredVisibleItems()
        state.visibleItemsSignature = signature
        state.searchSuggestions = buildSearchSuggestions(
            items: state.visibleItemsCache,
            query: state.searchQuery
        )
        if appLogger.isNoop == false {
            appLogger.withCategory("torrent-list").debug(
                "visibleItemsCache.updated",
                metadata: [
                    "visible": "\(state.visibleItemsCache.count)",
                    "itemsRevision": "\(state.itemsRevision)",
                    "metricsRevision": "\(state.metricsRevision)",
                    "filter": "\(state.selectedFilter.rawValue)",
                    "category": "\(state.selectedCategory.rawValue)",
                    "query": "\(state.normalizedSearchQuery)"
                ]
            )
        }
    }

    func buildSearchSuggestions(
        items: IdentifiedArrayOf<TorrentListItem.State>,
        query: String
    ) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(
            items
                .map(\.torrent.name)
                .filter { name in
                    guard trimmed.isEmpty == false else { return true }
                    return name.localizedCaseInsensitiveContains(trimmed) == false
                }
                .prefix(5)
        )
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
