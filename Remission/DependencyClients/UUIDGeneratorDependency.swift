#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    /// Dependency для генерации UUID, чтобы исключить прямые вызовы UUID() в редьюсерах.
    @DependencyClient
    struct UUIDGeneratorDependency: Sendable {
        var generate: @Sendable () -> UUID = { UUID() }
    }

    extension UUIDGeneratorDependency {
        static let placeholder: Self = Self(
            generate: {
                UUID()
            }
        )
    }

    extension UUIDGeneratorDependency: DependencyKey {
        static let liveValue: Self = placeholder
        static let previewValue: Self = placeholder
        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        var uuidGenerator: UUIDGeneratorDependency {
            get { self[UUIDGeneratorDependency.self] }
            set { self[UUIDGeneratorDependency.self] = newValue }
        }
    }
#endif
