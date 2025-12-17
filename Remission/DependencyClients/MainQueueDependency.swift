#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    /// Dependency для выполнения операций на главной очереди.
    @DependencyClient
    struct MainQueueDependency: Sendable {
        var async: @Sendable (@escaping @MainActor () -> Void) -> Void
        var asyncAfter: @Sendable (Duration, @escaping @MainActor () -> Void) -> Void
    }

    extension MainQueueDependency {
        static let placeholder: Self = Self(
            async: { operation in
                Task {
                    await MainActor.run {
                        operation()
                    }
                }
            },
            asyncAfter: { _, operation in
                Task {
                    await MainActor.run {
                        operation()
                    }
                }
            }
        )
    }

    extension MainQueueDependency: DependencyKey {
        static let liveValue: Self = Self(
            async: { operation in
                Task {
                    await MainActor.run {
                        operation()
                    }
                }
            },
            asyncAfter: { duration, operation in
                Task {
                    try await Task.sleep(for: duration)
                    await MainActor.run {
                        operation()
                    }
                }
            }
        )
        static let previewValue: Self = placeholder
        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        var mainQueueExecutor: MainQueueDependency {
            get { self[MainQueueDependency.self] }
            set { self[MainQueueDependency.self] = newValue }
        }
    }
#endif
