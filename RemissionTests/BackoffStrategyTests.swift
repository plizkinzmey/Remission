import Foundation
import Testing

@testable import Remission

@Suite("Backoff Strategy Tests")
struct BackoffStrategyTests {
    @Test(
        "Delay table and clamping",
        arguments: [
            (failures: -1, expected: Duration.seconds(1)),
            (failures: 0, expected: Duration.seconds(1)),
            (failures: 1, expected: Duration.seconds(1)),
            (failures: 2, expected: Duration.seconds(2)),
            (failures: 3, expected: Duration.seconds(4)),
            (failures: 4, expected: Duration.seconds(8)),
            (failures: 5, expected: Duration.seconds(16)),
            (failures: 6, expected: Duration.seconds(30)),
            (failures: 7, expected: Duration.seconds(30)),
            (failures: 100, expected: Duration.seconds(30))
        ]
    )
    func delayMatchesTable(input: (failures: Int, expected: Duration)) {
        let actual = BackoffStrategy.delay(for: input.failures)
        #expect(actual == input.expected)
    }
}
