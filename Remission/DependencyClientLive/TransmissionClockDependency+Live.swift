#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    #if canImport(Clocks)
        import Clocks
    #endif
    import Foundation

    extension TransmissionClockDependency: DependencyKey {
        static let liveValue: Self = Self(
            clock: {
                ContinuousClock()
            }
        )
    }

    extension TransmissionClockDependency {
        /// Для тестирования используется TestClock
        static let testValue: Self = Self(
            clock: {
                #if canImport(Clocks)
                    TestClock<Duration>()
                #else
                    ContinuousClock()
                #endif
            }
        )
    }
#endif
