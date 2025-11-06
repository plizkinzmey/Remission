#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
    import Foundation

    /// Универсальная зависимость для управления временем в приложении.
    /// Используется TransmissionClient и TCA-фичами для sleep/timers без прямой
    /// привязки к конкретной реализации Clock.
    @DependencyClient
    struct AppClockDependency: Sendable {
        /// Возвращает Clock для использования в эффектах.
        var clock: @Sendable () -> any Clock<Duration> = { ContinuousClock() }
    }

    extension AppClockDependency {
        /// Плейсхолдер для окружений без конфигурации.
        static let placeholder: Self = Self(
            clock: {
                ContinuousClock()
            }
        )

        /// Упрощённый конструктор тестовой зависимости с внешним TestClock.
        static func test(clock: some Clock<Duration>) -> Self {
            Self(
                clock: {
                    clock
                }
            )
        }
    }

    extension AppClockDependency: DependencyKey {
        static let liveValue: Self = Self(
            clock: {
                ContinuousClock()
            }
        )
        static let previewValue: Self = liveValue
        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        @preconcurrency var appClock: AppClockDependency {
            get { self[AppClockDependency.self] }
            set { self[AppClockDependency.self] = newValue }
        }
    }
#endif
