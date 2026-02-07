import ComposableArchitecture
import Dependencies
import Foundation
import UserNotifications

extension TorrentListReducer {
    var body: some ReducerOf<Self> {
        CombineReducers {
            Reduce<TorrentListReducer.State, TorrentListReducer.Action> { state, action in
                switch action {
                case .task:
                    if let environment = state.connectionEnvironment {
                        state.cacheKey = environment.cacheKey
                    }
                    if state.items.isEmpty {
                        state.phase = .loading
                    } else {
                        state.isAwaitingConnection = false
                    }
                    guard let serverID = state.serverID else {
                        return .none
                    }
                    return .merge(
                        loadPreferences(serverID: serverID),
                        observePreferences(serverID: serverID),
                        .run { _ in
                            do {
                                _ = try await notificationClient.requestAuthorization([
                                    .alert, .sound, .badge
                                ])
                            } catch {
                                // If notifications aren't available (or aren't configured in tests),
                                // we treat it as non-fatal and continue without them.
                            }
                        }
                    )

                case .teardown:
                    state.isRefreshing = false
                    state.hasLoadedPreferences = false
                    state.offlineState = nil
                    state.errorPresenter.banner = nil
                    state.pendingRemoveTorrentID = nil
                    state.removingTorrentIDs.removeAll()
                    state.inFlightCommands.removeAll()
                    state.verifyPendingIDs.removeAll()
                    state.isAwaitingConnection = false
                    updateVisibleItemsCache(state: &state)
                    return .merge(
                        .cancel(id: CancelID.fetch),
                        .cancel(id: CancelID.polling),
                        .cancel(id: CancelID.preferences),
                        .cancel(id: CancelID.preferencesUpdates),
                        .cancel(id: CancelID.cache)
                    )

                case .resetForReconnect:
                    state.isRefreshing = false
                    state.phase = .loading
                    state.items.removeAll()
                    state.storageSummary = nil
                    state.offlineState = nil
                    state.errorPresenter.banner = nil
                    state.pendingRemoveTorrentID = nil
                    state.removingTorrentIDs.removeAll()
                    state.inFlightCommands.removeAll()
                    state.verifyPendingIDs.removeAll()
                    state.lastSnapshotAt = nil
                    state.isAwaitingConnection = true
                    state.itemsRevision += 1
                    updateVisibleItemsCache(state: &state)
                    return .merge(
                        .cancel(id: CancelID.fetch),
                        .cancel(id: CancelID.polling)
                    )

                case .refreshRequested:
                    state.failedAttempts = 0
                    state.offlineState = nil
                    state.isRefreshing = true
                    return fetchTorrents(state: &state, trigger: .manualRefresh)

                case .commandRefreshRequested:
                    return fetchTorrents(state: &state, trigger: .command)

                case .searchQueryChanged(let query):
                    state.searchQuery = query
                    updateVisibleItemsCache(state: &state)
                    return .none

                case .toggleSearchField:
                    state.isSearchFieldVisible.toggle()
                    if state.isSearchFieldVisible == false {
                        state.searchQuery = ""
                    }
                    updateVisibleItemsCache(state: &state)
                    return .none

                case .hideSearchField:
                    state.isSearchFieldVisible = false
                    state.searchQuery = ""
                    updateVisibleItemsCache(state: &state)
                    return .none

                case .filterChanged(let filter):
                    state.selectedFilter = filter
                    updateVisibleItemsCache(state: &state)
                    return .none

                case .categoryChanged(let category):
                    state.selectedCategory = category
                    updateVisibleItemsCache(state: &state)
                    return .none

                case .rowTapped(let id):
                    return .send(.delegate(.openTorrent(id)))

                case .startTapped(let id):
                    return performCommand(.start, torrentID: id, state: &state)

                case .pauseTapped(let id):
                    return performCommand(.pause, torrentID: id, state: &state)

                case .verifyTapped(let id):
                    state.verifyPendingIDs.insert(id)
                    if appLogger.isNoop == false {
                        appLogger.withCategory("torrent-list").debug(
                            "verifyTapped",
                            metadata: [
                                "id": "\(id.rawValue)",
                                "pendingCount": "\(state.verifyPendingIDs.count)",
                                "inFlightCount": "\(state.inFlightCommands.count)"
                            ]
                        )
                    }
                    return performCommand(.verify, torrentID: id, state: &state)

                case .removeTapped(let id):
                    let name = state.items[id: id]?.torrent.name ?? ""
                    state.pendingRemoveTorrentID = id
                    state.removeConfirmation = .removeTorrent(name: name)
                    return .none

                case .removeConfirmation(.presented(.deleteTorrentOnly)):
                    state.removeConfirmation = nil
                    guard let id = state.pendingRemoveTorrentID else { return .none }
                    state.pendingRemoveTorrentID = nil
                    state.removingTorrentIDs.insert(id)
                    if var item = state.items[id: id] {
                        item.isRemoving = true
                        state.items[id: id] = item
                    }
                    return performCommand(.remove(deleteData: false), torrentID: id, state: &state)

                case .removeConfirmation(.presented(.deleteWithData)):
                    state.removeConfirmation = nil
                    guard let id = state.pendingRemoveTorrentID else { return .none }
                    state.pendingRemoveTorrentID = nil
                    state.removingTorrentIDs.insert(id)
                    if var item = state.items[id: id] {
                        item.isRemoving = true
                        state.items[id: id] = item
                    }
                    return performCommand(.remove(deleteData: true), torrentID: id, state: &state)

                case .removeConfirmation(.presented(.cancel)):
                    state.pendingRemoveTorrentID = nil
                    state.removeConfirmation = nil
                    return .none

                case .removeConfirmation:
                    return .none

                case .commandResponse(_, .success):
                    return .send(.commandRefreshRequested)

                case .commandResponse(let id, .failure(let error)):
                    state.inFlightCommands.removeValue(forKey: id)
                    state.removingTorrentIDs.remove(id)
                    state.verifyPendingIDs.remove(id)
                    if appLogger.isNoop == false {
                        appLogger.withCategory("torrent-list").debug(
                            "commandResponse.failure",
                            metadata: [
                                "id": "\(id.rawValue)",
                                "pendingCount": "\(state.verifyPendingIDs.count)",
                                "inFlightCount": "\(state.inFlightCommands.count)",
                                "error": "\(error.message)"
                            ]
                        )
                    }
                    if var item = state.items[id: id] {
                        item.isRemoving = false
                        state.items[id: id] = item
                    }
                    let message = error.message
                    return .send(
                        .errorPresenter(
                            .showAlert(
                                title: L10n.tr("torrentDetail.error.title"),
                                message: message,
                                retry: nil
                            )
                        )
                    )

                case .addTorrentButtonTapped:
                    return .send(.delegate(.addTorrentRequested))

                case .pollingTick:
                    if appLogger.isNoop == false {
                        appLogger.withCategory("torrent-list").debug(
                            "pollingTick",
                            metadata: [
                                "items": "\(state.items.count)",
                                "visible": "\(state.visibleItemsCache.count)",
                                "itemsRevision": "\(state.itemsRevision)",
                                "metricsRevision": "\(state.metricsRevision)",
                                "interval": "\(state.pollingInterval)"
                            ]
                        )
                    }
                    return fetchTorrents(state: &state, trigger: .polling)

                case .userPreferencesResponse(.success(let preferences)):
                    let newInterval = duration(from: preferences.pollingInterval)
                    let newAutoRefresh = preferences.isAutoRefreshEnabled
                    let intervalChanged = state.pollingInterval != newInterval
                    let autoRefreshChanged = state.isPollingEnabled != newAutoRefresh
                    state.pollingInterval = newInterval
                    state.isPollingEnabled = newAutoRefresh
                    if intervalChanged {
                        state.adaptivePollingInterval = nil
                    }

                    if state.hasLoadedPreferences == false {
                        state.hasLoadedPreferences = true
                        return fetchTorrents(state: &state, trigger: .initial)
                    }

                    guard intervalChanged || autoRefreshChanged else {
                        return .none
                    }
                    return restartPolling(state: &state)

                case .userPreferencesResponse(.failure(let error)):
                    let effect = fetchTorrents(state: &state, trigger: .initial)
                    let message = describe(error)
                    let alert = Effect<Action>.send(
                        .errorPresenter(
                            .showAlert(
                                title: L10n.tr("torrentList.alert.preferencesFailed.title"),
                                message: message,
                                retry: .refresh
                            )
                        )
                    )
                    return .merge(effect, alert)

                case .goOffline(let message):
                    let offline = OfflineState(
                        message: message,
                        lastUpdatedAt: state.lastSnapshotAt
                    )
                    state.offlineState = offline
                    state.phase = .offline(offline)
                    state.isRefreshing = false
                    state.isAwaitingConnection = false
                    state.items.removeAll()
                    state.storageSummary = nil
                    state.itemsRevision += 1
                    updateVisibleItemsCache(state: &state)
                    let banner = Effect<Action>.send(
                        .errorPresenter(
                            .showBanner(
                                message: message,
                                retry: .refresh
                            )
                        )
                    )
                    return banner

                case .torrentsResponse(.success(let payload)):
                    let previousItems = state.items

                    // Проверяем, был ли список загружен ранее. Если phase == .loaded, значит это обновление (polling/refresh),
                    // и мы должны уведомлять о новых торрентах (добавленных на другом устройстве).
                    // Если нет (первая загрузка), уведомления для "новых" (всех) торрентов подавляем.
                    let wasLoaded = state.phase == .loaded

                    state.isRefreshing = false
                    state.isAwaitingConnection = false
                    state.errorPresenter.banner = nil
                    state.lastSnapshotAt = payload.snapshotDate ?? state.lastSnapshotAt

                    let mergeResult = merge(
                        state: &state,
                        with: payload.torrents,
                        removingIDs: state.removingTorrentIDs
                    )
                    let hasVisibleChanges = mergeResult.didChange
                    if hasVisibleChanges {
                        state.items = mergeResult.items
                        state.itemsRevision += 1
                        updateVisibleItemsCache(state: &state)
                    }
                    if appLogger.isNoop == false {
                        appLogger.withCategory("torrent-list").debug(
                            "torrentsResponse.success",
                            metadata: [
                                "torrents": "\(payload.torrents.count)",
                                "hasVisibleChanges": "\(hasVisibleChanges)",
                                "itemsRevision": "\(state.itemsRevision)",
                                "metricsRevision": "\(state.metricsRevision)",
                                "visible": "\(state.visibleItemsCache.count)",
                                "filter": "\(state.selectedFilter.rawValue)",
                                "category": "\(state.selectedCategory.rawValue)",
                                "query": "\(state.normalizedSearchQuery)"
                            ]
                        )

                        if let sample = payload.torrents.first(where: { $0.status == .downloading })
                            ?? payload.torrents.first
                        {
                            let previous = previousItems[id: sample.id]?.torrent
                            let prevPercent = previous?.summary.progress.percentDone ?? -1
                            let prevDown = previous?.summary.transfer.downloadRate ?? -1
                            let prevUp = previous?.summary.transfer.uploadRate ?? -1
                            appLogger.withCategory("torrent-list").debug(
                                "torrentsResponse.sample",
                                metadata: [
                                    "id": "\(sample.id.rawValue)",
                                    "status": "\(sample.status)",
                                    "percent": "\(sample.summary.progress.percentDone)",
                                    "rateDown": "\(sample.summary.transfer.downloadRate)",
                                    "rateUp": "\(sample.summary.transfer.uploadRate)",
                                    "prevPercent": "\(prevPercent)",
                                    "prevDown": "\(prevDown)",
                                    "prevUp": "\(prevUp)"
                                ]
                            )
                        }
                    }

                    let notificationsEffect: Effect<Action> = .run { [items = state.items] _ in
                        for newItem in items {
                            if let oldItem = previousItems[id: newItem.id] {
                                // 1. Логика для уже существовавших торрентов (изменение состояния)
                                let wasNotFinished =
                                    oldItem.torrent.summary.progress.percentDone < 1.0
                                let isFinished = newItem.torrent.summary.progress.percentDone >= 1.0
                                if wasNotFinished && isFinished {
                                    try? await notificationClient.sendNotification(
                                        L10n.tr("torrentList.notification.completed.title"),
                                        L10n.tr(
                                            "torrentList.notification.completed.body",
                                            newItem.torrent.name
                                        ),
                                        "completed-\(newItem.id.rawValue)"
                                    )
                                }

                                // Check for error
                                let hadNoError = oldItem.torrent.error == 0
                                let hasError = newItem.torrent.error != 0
                                if hadNoError && hasError {
                                    try? await notificationClient.sendNotification(
                                        L10n.tr("torrentList.notification.error.title"),
                                        newItem.torrent.errorString.isEmpty
                                            ? L10n.tr(
                                                "torrentList.notification.error.body",
                                                newItem.torrent.name
                                            )
                                            : newItem.torrent.errorString,
                                        "error-\(newItem.id.rawValue)"
                                    )
                                }
                            } else if wasLoaded {
                                // 2. Логика для НОВЫХ торрентов (добавленных удаленно),
                                // но только если это не первый запуск приложения.
                                if newItem.torrent.summary.progress.percentDone >= 1.0 {
                                    try? await notificationClient.sendNotification(
                                        L10n.tr("torrentList.notification.completed.title"),
                                        L10n.tr(
                                            "torrentList.notification.completed.body",
                                            newItem.torrent.name
                                        ),
                                        "completed-\(newItem.id.rawValue)"
                                    )
                                }

                                if newItem.torrent.error != 0 {
                                    try? await notificationClient.sendNotification(
                                        L10n.tr("torrentList.notification.error.title"),
                                        newItem.torrent.errorString.isEmpty
                                            ? L10n.tr(
                                                "torrentList.notification.error.body",
                                                newItem.torrent.name
                                            )
                                            : newItem.torrent.errorString,
                                        "error-\(newItem.id.rawValue)"
                                    )
                                }
                            }
                        }
                    }

                    let currentIDs = Set(state.items.map(\.id))
                    state.removingTorrentIDs.formIntersection(currentIDs)
                    state.verifyPendingIDs.formIntersection(currentIDs)
                    var updatedInFlight: [Torrent.Identifier: InFlightCommand] = [:]
                    updatedInFlight.reserveCapacity(state.inFlightCommands.count)
                    for (id, inFlight0) in state.inFlightCommands {
                        guard let item = state.items[id: id] else { continue }
                        switch inFlight0.command {
                        case .remove:
                            updatedInFlight[id] = inFlight0

                        case .start, .pause:
                            // Old behavior: keep busy until status diverges from the one we started with.
                            if item.torrent.status == inFlight0.initialStatus {
                                updatedInFlight[id] = inFlight0
                            }

                        case .verify:
                            // Hard rule (matches UX expectation):
                            // once user taps verify, keep the command "busy" until Transmission
                            // reports that the check actually started.
                            if item.torrent.status == .checkWaiting
                                || item.torrent.status == .checking
                            {
                                // Drop in-flight; UI stays busy via status while checking runs.
                                continue
                            }
                            updatedInFlight[id] = inFlight0
                        }
                    }
                    state.inFlightCommands = updatedInFlight

                    // Clear optimistic verify pending once the backend reports check start.
                    for item in state.items {
                        guard state.verifyPendingIDs.contains(item.id) else { continue }
                        if item.torrent.status == .checkWaiting
                            || item.torrent.status == .checking
                        {
                            state.verifyPendingIDs.remove(item.id)
                        }
                    }
                    if appLogger.isNoop == false {
                        appLogger.withCategory("torrent-list").debug(
                            "torrentsResponse.verifyState",
                            metadata: [
                                "pendingCount": "\(state.verifyPendingIDs.count)",
                                "inFlightCount": "\(state.inFlightCommands.count)"
                            ]
                        )
                    }
                    if payload.isFromCache == false {
                        state.failedAttempts = 0
                        state.offlineState = nil
                        state.phase = .loaded
                        state.isAwaitingConnection = false
                    } else if let offline = state.offlineState {
                        state.phase = .offline(offline)
                    } else {
                        state.phase = .loaded
                        state.isAwaitingConnection = false
                    }
                    guard payload.isFromCache == false,
                        state.isPollingEnabled,
                        state.connectionEnvironment != nil
                    else {
                        let finalEffect =
                            payload.isFromCache
                            ? .none : Effect<Action>.cancel(id: CancelID.polling)
                        return .merge(notificationsEffect, finalEffect)
                    }
                    let nextInterval = nextAdaptiveInterval(
                        state: &state,
                        hasVisibleChanges: hasVisibleChanges
                    )
                    return .merge(notificationsEffect, schedulePolling(after: nextInterval))

                case .storageUpdated(let summary):
                    state.storageSummary = summary
                    return .none

                case .torrentsResponse(.failure(let error)):
                    if error is CancellationError {
                        return .none
                    }
                    let message = describe(error)
                    state.isRefreshing = false
                    state.isAwaitingConnection = false
                    state.phase = .error(message)
                    state.failedAttempts += 1
                    let offline = OfflineState(
                        message: message,
                        lastUpdatedAt: state.lastSnapshotAt
                    )
                    state.offlineState = offline
                    state.phase = .offline(offline)
                    state.errorPresenter.banner = .init(
                        message: message,
                        retry: .refresh
                    )
                    guard state.isPollingEnabled,
                        state.connectionEnvironment != nil,
                        state.failedAttempts < maxRetryAttempts
                    else {
                        return .cancel(id: CancelID.polling)
                    }
                    let retryEffect = schedulePolling(
                        after: backoffDelay(for: state.failedAttempts))
                    return retryEffect

                case .errorPresenter(.retryRequested(.refresh)):
                    return .send(.refreshRequested)

                case .errorPresenter:
                    return .none

                case .delegate(.detailUpdated(let torrent)):
                    return handleDetailUpdated(
                        state: &state,
                        torrent: torrent
                    )

                case .delegate(.added(let result)):
                    return handleTorrentAdded(
                        state: &state,
                        result: result
                    )

                case .delegate(.detailRemoved(let identifier)):
                    return handleDetailRemoved(
                        state: &state,
                        identifier: identifier
                    )

                case .delegate:
                    return .none
                }
            }
            .ifLet(
                \TorrentListReducer.State.$removeConfirmation,
                action: \.removeConfirmation
            )
            Scope(
                state: \TorrentListReducer.State.errorPresenter,
                action: \.errorPresenter
            ) {
                ErrorPresenter<TorrentListReducer.Retry>()
            }
        }
    }
}
