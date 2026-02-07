import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros

    /// Хранилище диагностических логов с поддержкой фильтрации и очистки.
    @DependencyClient
    struct DiagnosticsLogStore: Sendable {
        var load: @Sendable (DiagnosticsLogFilter) async throws -> [DiagnosticsLogEntry] = { _ in []
        }
        var observe: @Sendable (DiagnosticsLogFilter) async -> AsyncStream<[DiagnosticsLogEntry]> =
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
            let defaultsBox = DiagnosticsUserDefaultsBox(defaults: defaults)
            let store = PersistentDiagnosticsLogStore(defaults: defaultsBox, maxEntries: maxEntries)

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
        static let liveValue: DiagnosticsLogStore = .persistent()
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
        private var entries: [DiagnosticsLogEntry]
        private let maxEntries: Int
        private var observers:
            [UUID: (DiagnosticsLogFilter, AsyncStream<[DiagnosticsLogEntry]>.Continuation)] =
                [:]

        init(maxEntries: Int, seed: [DiagnosticsLogEntry] = []) {
            self.maxEntries = maxEntries
            self.entries = Array(seed.suffix(maxEntries))
        }

        func append(_ entry: DiagnosticsLogEntry) {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            notifyObservers()
        }

        func clear() {
            entries.removeAll()
            notifyObservers()
        }

        func snapshot(filter: DiagnosticsLogFilter) -> [DiagnosticsLogEntry] {
            apply(filter: filter, to: entries)
        }

        func observe(filter: DiagnosticsLogFilter) -> AsyncStream<[DiagnosticsLogEntry]> {
            AsyncStream { continuation in
                let id = UUID()
                observers[id] = (filter, continuation)

                continuation.onTermination = { [weak self] _ in
                    Task { await self?.removeObserver(id) }
                }

                continuation.yield(apply(filter: filter, to: entries))
            }
        }

        private func removeObserver(_ id: UUID) {
            observers.removeValue(forKey: id)
        }

        private func notifyObservers() {
            for value in observers.values {
                let (filter, continuation) = value
                continuation.yield(apply(filter: filter, to: entries))
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
        private enum StorageKey {
            static let entries = "diagnostics_log_entries"
        }

        private let defaults: DiagnosticsUserDefaultsBox
        private let maxEntries: Int
        private var entries: [DiagnosticsLogEntry]
        private var observers:
            [UUID: (DiagnosticsLogFilter, AsyncStream<[DiagnosticsLogEntry]>.Continuation)] =
                [:]

        init(defaults: DiagnosticsUserDefaultsBox, maxEntries: Int) {
            self.defaults = defaults
            self.maxEntries = maxEntries
            self.entries = []
            self.entries = Self.loadSnapshot(defaults: defaults, maxEntries: maxEntries)
        }

        func append(_ entry: DiagnosticsLogEntry) {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            persist()
            notifyObservers()
        }

        func clear() throws {
            entries.removeAll()
            defaults.remove(StorageKey.entries)
            notifyObservers()
        }

        func snapshot(filter: DiagnosticsLogFilter) -> [DiagnosticsLogEntry] {
            apply(filter: filter, to: entries)
        }

        func observe(filter: DiagnosticsLogFilter) -> AsyncStream<[DiagnosticsLogEntry]> {
            AsyncStream { continuation in
                let id = UUID()
                observers[id] = (filter, continuation)

                continuation.onTermination = { [weak self] _ in
                    Task { await self?.removeObserver(id) }
                }

                continuation.yield(apply(filter: filter, to: entries))
            }
        }

        private func removeObserver(_ id: UUID) {
            observers.removeValue(forKey: id)
        }

        private func notifyObservers() {
            for value in observers.values {
                let (filter, continuation) = value
                continuation.yield(apply(filter: filter, to: entries))
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

        private func persist() {
            do {
                let data = try JSONEncoder().encode(entries)
                defaults.set(data, forKey: StorageKey.entries)
            } catch {
                defaults.remove(StorageKey.entries)
            }
        }

        private static func loadSnapshot(
            defaults: DiagnosticsUserDefaultsBox,
            maxEntries: Int
        ) -> [DiagnosticsLogEntry] {
            guard let data = defaults.data(StorageKey.entries) else {
                return []
            }
            do {
                let decoded = try JSONDecoder().decode([DiagnosticsLogEntry].self, from: data)
                return Array(decoded.suffix(maxEntries))
            } catch {
                defaults.remove(StorageKey.entries)
                return []
            }
        }
    }

    private final class DiagnosticsUserDefaultsBox: @unchecked Sendable {
        // Safety invariant:
        // - `UserDefaults` is thread-safe for concurrent access.
        // - This wrapper only provides a minimal API for `Data` get/set/remove.
        private let defaults: UserDefaults

        init(defaults: UserDefaults) {
            self.defaults = defaults
        }

        func data(_ key: String) -> Data? {
            defaults.data(forKey: key)
        }

        func set(_ data: Data, forKey key: String) {
            defaults.set(data, forKey: key)
        }

        func remove(_ key: String) {
            defaults.removeObject(forKey: key)
        }
    }
#endif
