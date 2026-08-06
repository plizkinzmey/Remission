import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros

    /// Хранилище диагностических логов с поддержкой фильтрации и очистки.
    @DependencyClient
    struct DiagnosticsLogStore: Sendable {
        enum StreamEvent: Equatable, Sendable {
            case appended(DiagnosticsLogEntry)
            case dropped([UUID])
            case cleared
        }

        var load: @Sendable (DiagnosticsLogFilter) async throws -> [DiagnosticsLogEntry] = { _ in []
        }
        var observe: @Sendable (DiagnosticsLogFilter) async -> AsyncStream<StreamEvent> =
            { _ in
                AsyncStream { $0.finish() }
            }
        var append: @Sendable (DiagnosticsLogEntry) async -> Void = { _ in }
        var clear: @Sendable () async throws -> Void = {}
        var maxEntries: Int = 500
    }

    extension DiagnosticsLogStore {
        static func persistent(
            defaults: UserDefaults = .standard,
            maxEntries: Int = 500
        ) -> DiagnosticsLogStore {
            let store = PersistentDiagnosticsLogStore(maxEntries: maxEntries)

            return DiagnosticsLogStore(
                load: { filter in
                    await store.snapshot(filter: filter)
                },
                observe: { filter in
                    await store.observe(filter: filter)
                },
                append: { entry in
                    await store.append(entry)
                },
                clear: {
                    try await store.clear()
                },
                maxEntries: maxEntries
            )
        }

        static func live(maxEntries: Int = 500) -> DiagnosticsLogStore {
            let buffer = DiagnosticsLogBuffer(maxEntries: maxEntries)

            return DiagnosticsLogStore(
                load: { filter in
                    await buffer.snapshot(filter: filter)
                },
                observe: { filter in
                    await buffer.observe(filter: filter)
                },
                append: { entry in
                    await buffer.append(entry)
                },
                clear: {
                    await buffer.clear()
                },
                maxEntries: maxEntries
            )
        }

        static func inMemory(
            initialEntries: [DiagnosticsLogEntry] = [],
            maxEntries: Int = 500
        ) -> DiagnosticsLogStore {
            let buffer = DiagnosticsLogBuffer(maxEntries: maxEntries, seed: initialEntries)

            return DiagnosticsLogStore(
                load: { filter in
                    await buffer.snapshot(filter: filter)
                },
                observe: { filter in
                    await buffer.observe(filter: filter)
                },
                append: { entry in
                    await buffer.append(entry)
                },
                clear: {
                    await buffer.clear()
                },
                maxEntries: maxEntries
            )
        }

        static let placeholder: DiagnosticsLogStore = .inMemory()

        /// Синхронный sink для AppLogger: в фоновом Task добавляет записи в хранилище.
        func makeSink() -> (@Sendable (DiagnosticsLogEntry) -> Void) {
            { entry in
                // Intentionally not `Task.detached`:
                // we don't need to escape priority/context, and this is easier to reason about.
                Task {
                    await append(entry)
                }
            }
        }
    }

    extension DiagnosticsLogStore: DependencyKey {
        static var liveValue: DiagnosticsLogStore {
            .persistent(defaults: AppStorageNamespace.live().userDefaults())
        }
        static let previewValue: DiagnosticsLogStore = .placeholder
        static let testValue: DiagnosticsLogStore = .inMemory()
    }

    extension DependencyValues {
        var diagnosticsLogStore: DiagnosticsLogStore {
            get { self[DiagnosticsLogStore.self] }
            set { self[DiagnosticsLogStore.self] = newValue }
        }
    }

    /// Актор, который хранит лог-записи в кольцевом буфере и нотифицирует подписчиков.
    actor DiagnosticsLogBuffer {
        private struct Observer {
            let filter: DiagnosticsLogFilter
            let continuation: AsyncStream<DiagnosticsLogStore.StreamEvent>.Continuation
        }

        private var entries: [DiagnosticsLogEntry]
        private let maxEntries: Int
        private var observers: [UUID: Observer] = [:]

        init(maxEntries: Int, seed: [DiagnosticsLogEntry] = []) {
            self.maxEntries = maxEntries
            self.entries = Array(seed.suffix(maxEntries))
        }

        func append(_ entry: DiagnosticsLogEntry) {
            entries.append(entry)
            var droppedIDs: [UUID] = []
            if entries.count > maxEntries {
                let dropCount = entries.count - maxEntries
                droppedIDs = entries.prefix(dropCount).map(\.id)
                entries.removeFirst(dropCount)
            }
            notifyObservers(appended: entry, droppedIDs: droppedIDs)
        }

        func clear() {
            entries.removeAll()
            notifyObserversCleared()
        }

        func snapshot(filter: DiagnosticsLogFilter) -> [DiagnosticsLogEntry] {
            apply(filter: filter, to: entries)
        }

        func observe(filter: DiagnosticsLogFilter) -> AsyncStream<DiagnosticsLogStore.StreamEvent> {
            AsyncStream { continuation in
                let id = UUID()
                observers[id] = Observer(filter: filter, continuation: continuation)

                continuation.onTermination = { [weak self] _ in
                    Task { await self?.removeObserver(id) }
                }
            }
        }

        private func removeObserver(_ id: UUID) {
            observers.removeValue(forKey: id)
        }

        private func notifyObservers(appended entry: DiagnosticsLogEntry, droppedIDs: [UUID]) {
            for observer in observers.values {
                let filter = observer.filter
                let continuation = observer.continuation
                if droppedIDs.isEmpty == false {
                    continuation.yield(.dropped(droppedIDs))
                }
                if filter.matches(entry) {
                    continuation.yield(.appended(entry))
                }
            }
        }

        private func notifyObserversCleared() {
            for observer in observers.values {
                observer.continuation.yield(.cleared)
            }
        }

        private func apply(
            filter: DiagnosticsLogFilter,
            to entries: [DiagnosticsLogEntry]
        ) -> [DiagnosticsLogEntry] {
            entries
                .reversed()
                .filter { filter.matches($0) }
        }
    }

    private actor PersistentDiagnosticsLogStore {
        private struct Observer {
            let filter: DiagnosticsLogFilter
            let continuation: AsyncStream<DiagnosticsLogStore.StreamEvent>.Continuation
        }

        private enum StorageKey {
            static let entries = "diagnostics_log_entries"
        }

        private let store: UserDefaultsStore<[DiagnosticsLogEntry]>
        private let maxEntries: Int
        private var entries: [DiagnosticsLogEntry]
        private var observers: [UUID: Observer] = [:]
        private var isLoaded = false

        init(maxEntries: Int) {
            self.store = UserDefaultsStore(key: StorageKey.entries)
            self.maxEntries = maxEntries
            self.entries = []
        }

        private func ensureLoaded() async {
            guard !isLoaded else { return }
            isLoaded = true
            let loaded = await store.load() ?? []
            self.entries = Array(loaded.suffix(maxEntries))
        }

        func append(_ entry: DiagnosticsLogEntry) async {
            await ensureLoaded()
            entries.append(entry)
            var droppedIDs: [UUID] = []
            if entries.count > maxEntries {
                let dropCount = entries.count - maxEntries
                droppedIDs = entries.prefix(dropCount).map(\.id)
                entries.removeFirst(dropCount)
            }
            await persist()
            notifyObservers(appended: entry, droppedIDs: droppedIDs)
        }

        func clear() async throws {
            await ensureLoaded()
            entries.removeAll()
            await store.remove()
            notifyObserversCleared()
        }

        func snapshot(filter: DiagnosticsLogFilter) async -> [DiagnosticsLogEntry] {
            await ensureLoaded()
            return apply(filter: filter, to: entries)
        }

        func observe(filter: DiagnosticsLogFilter) -> AsyncStream<DiagnosticsLogStore.StreamEvent> {
            AsyncStream { continuation in
                let id = UUID()
                Task { [weak self] in
                    await self?.addObserver(id: id, filter: filter, continuation: continuation)
                }

                continuation.onTermination = { [weak self] _ in
                    Task { await self?.removeObserver(id) }
                }
            }
        }

        private func addObserver(
            id: UUID, filter: DiagnosticsLogFilter,
            continuation: AsyncStream<DiagnosticsLogStore.StreamEvent>.Continuation
        ) async {
            await ensureLoaded()
            observers[id] = Observer(filter: filter, continuation: continuation)
        }

        private func removeObserver(_ id: UUID) {
            observers.removeValue(forKey: id)
        }

        private func notifyObservers(appended entry: DiagnosticsLogEntry, droppedIDs: [UUID]) {
            for observer in observers.values {
                let filter = observer.filter
                let continuation = observer.continuation
                if droppedIDs.isEmpty == false {
                    continuation.yield(.dropped(droppedIDs))
                }
                if filter.matches(entry) {
                    continuation.yield(.appended(entry))
                }
            }
        }

        private func notifyObserversCleared() {
            for observer in observers.values {
                observer.continuation.yield(.cleared)
            }
        }

        private func apply(
            filter: DiagnosticsLogFilter,
            to entries: [DiagnosticsLogEntry]
        ) -> [DiagnosticsLogEntry] {
            entries
                .reversed()
                .filter { filter.matches($0) }
        }

        private func persist() async {
            do {
                try await store.save(entries)
            } catch {
                await store.remove()
            }
        }
    }
#endif
