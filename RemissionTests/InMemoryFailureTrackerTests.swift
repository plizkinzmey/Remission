import Testing

@testable import Remission

@Suite("In-Memory Failure Tracker Tests")
struct InMemoryFailureTrackerTests {
    private enum Operation: String, Hashable, Sendable {
        case fetch
        case update
    }

    // Проверяет markFailure/shouldFail и очистку конкретной операции.
    @Test
    func markAndClearFailure() async {
        let tracker = InMemoryFailureTracker<Operation>()

        #expect(await tracker.shouldFail(.fetch) == false)
        await tracker.markFailure(.fetch)
        #expect(await tracker.shouldFail(.fetch))

        await tracker.clearFailure(.fetch)
        #expect(await tracker.shouldFail(.fetch) == false)
    }

    // Проверяет resetFailures для нескольких операций.
    @Test
    func resetFailuresClearsAllOperations() async {
        let tracker = InMemoryFailureTracker<Operation>()
        await tracker.markFailure(.fetch)
        await tracker.markFailure(.update)

        await tracker.resetFailures()
        #expect(await tracker.shouldFail(.fetch) == false)
        #expect(await tracker.shouldFail(.update) == false)
    }
}
