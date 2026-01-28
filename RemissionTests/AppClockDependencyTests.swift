import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("App Clock Dependency Tests")
struct AppClockDependencyTests {
    // Проверяет, что test(clock:) возвращает clock того же типа с тем же now.
    @Test
    func testClockIsReturnedByDependency() {
        let clock = TestClock<Duration>()
        let dependency = AppClockDependency.test(clock: clock)

        guard let returned = dependency.clock() as? TestClock<Duration> else {
            Issue.record("Ожидали TestClock из зависимости")
            return
        }

        #expect(returned.now == clock.now)
    }
}
