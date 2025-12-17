#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    /// Dependency для получения текущего времени.
    @DependencyClient
    struct DateProviderDependency: Sendable {
        var now: @Sendable () -> Date = { Date() }
    }

    extension DateProviderDependency {
        static let placeholder: Self = Self(
            now: {
                Date()
            }
        )
    }

    extension DateProviderDependency: DependencyKey {
        static let liveValue: Self = placeholder
        static let previewValue: Self = placeholder
        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        var dateProvider: DateProviderDependency {
            get { self[DateProviderDependency.self] }
            set { self[DateProviderDependency.self] = newValue }
        }
    }
#endif
