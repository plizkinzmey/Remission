#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    /// Dependency для инъекции Clock используется в TransmissionClient для retry логики.
    /// Позволяет тестам использовать TestClock для детерминированного управления временем,
    /// а production-коду — ContinuousClock для системных часов.
    struct TransmissionClockDependency: Sendable {
        /// Возвращает экземпляр Clock для использования в retry логике.
        /// Clock — встроенный протокол Swift 5.9+ для работы с временем в async коде.
        var clock: @Sendable () -> any Clock<Duration> = { ContinuousClock() }
    }

    extension TransmissionClockDependency {
        /// Placeholder для использования в ошибочных путях.
        static let placeholder: Self = Self(
            clock: {
                ContinuousClock()
            }
        )
    }

    // Экспонируем dependency в DependencyValues
    extension DependencyValues {
        @preconcurrency var transmissionClock: TransmissionClockDependency {
            get { self[TransmissionClockDependency.self] }
            set { self[TransmissionClockDependency.self] = newValue }
        }
    }
#endif
