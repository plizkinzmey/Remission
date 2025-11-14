import Foundation

/// Thread-safe счётчик вызовов, используемый в тестах для проверки количества fetch запросов.
actor FetchCounter {
    private var storage = 0

    @discardableResult
    func increment() -> Int {
        storage += 1
        return storage
    }

    var value: Int {
        storage
    }
}

/// Позволяет тестам фиксировать отменённые задачи (например, in-flight fetch).
actor CancellationRecorder {
    private var cancelled: Set<Int> = []

    func markCancelled(_ call: Int) {
        cancelled.insert(call)
    }

    func wasCancelled(call: Int) -> Bool {
        cancelled.contains(call)
    }
}
