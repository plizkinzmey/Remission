import Foundation
import Testing

@testable import Remission

@Suite("ServerConnectionProbe Backoff Tests")
struct ServerConnectionProbeTests {
    @Test("Экспоненциальная задержка удваивается на каждой попытке")
    func exponentialBackoffDoublesDelay() {
        var calculator = ServerConnectionProbe.ExponentialBackoffCalculator(
            initialDelay: .seconds(1)
        )
        let delays = calculator.collectDelays(count: 3)
        #expect(delays == [.seconds(1), .seconds(2), .seconds(4)])
    }
}
