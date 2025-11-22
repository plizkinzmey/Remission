import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

/// Receives preferences and connection responses in any order with exhaustivity off.
/// Helper assumes store.exhaustivity is already set to .off by caller.
/// Thread-safe box for recording values in async tests.
final class ServerDetailLockedValue<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&storage)
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Manages multiple AsyncStream continuations for preferences observation in tests.
actor ServerDetailPreferencesContinuationBox {
    private var continuations: [AsyncStream<UserPreferences>.Continuation] = []

    func set(_ continuation: AsyncStream<UserPreferences>.Continuation) {
        continuations.append(continuation)
    }

    func yield(_ preferences: UserPreferences) {
        for continuation in continuations {
            continuation.yield(preferences)
        }
    }

    func finish() {
        for continuation in continuations {
            continuation.finish()
        }
        continuations.removeAll()
    }
}

extension UserPreferencesRepository {
    /// Test helper scoped to ServerDetail tests to avoid collisions with other extensions.
    static func serverDetailTestValue(preferences: UserPreferences) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }
}
