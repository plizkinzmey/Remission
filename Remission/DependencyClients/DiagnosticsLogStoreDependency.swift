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
                Task.detached {
                    await append(entry)
                }
            }
        }
    }

    extension DiagnosticsLogStore: DependencyKey {
        static let liveValue: DiagnosticsLogStore = .live()
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
#endif
