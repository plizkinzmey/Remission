import Foundation

/// Универсальный трекер ошибок для in-memory репозиториев.
/// Используется в тестах и превью для симуляции сбоев конкретных операций.
actor InMemoryFailureTracker<Operation: Hashable & Sendable> {
    private var failedOperations: Set<Operation> = []

    func markFailure(_ operation: Operation) {
        failedOperations.insert(operation)
    }

    func clearFailure(_ operation: Operation) {
        failedOperations.remove(operation)
    }

    func resetFailures() {
        failedOperations.removeAll()
    }

    func shouldFail(_ operation: Operation) -> Bool {
        failedOperations.contains(operation)
    }
}
