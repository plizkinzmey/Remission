import Foundation

// MARK: - Session Repository (In-Memory)

actor InMemorySessionRepositoryStore {
    enum Operation: Hashable {
        case performHandshake
        case fetchState
        case updateState
        case checkCompatibility
    }

    private(set) var handshake: SessionRepository.Handshake
    private(set) var state: SessionState
    private(set) var compatibility: SessionRepository.Compatibility
    private let failureTracker = InMemoryFailureTracker<Operation>()

    init(
        handshake: SessionRepository.Handshake,
        state: SessionState,
        compatibility: SessionRepository.Compatibility
    ) {
        self.handshake = handshake
        self.state = state
        self.compatibility = compatibility
    }

    func setState(_ state: SessionState) {
        self.state = state
    }

    func setHandshake(_ handshake: SessionRepository.Handshake) {
        self.handshake = handshake
    }

    func setCompatibility(_ compatibility: SessionRepository.Compatibility) {
        self.compatibility = compatibility
    }

    func markFailure(_ operation: Operation) async {
        await failureTracker.markFailure(operation)
    }

    func clearFailure(_ operation: Operation) async {
        await failureTracker.clearFailure(operation)
    }

    func shouldFail(_ operation: Operation) async -> Bool {
        await failureTracker.shouldFail(operation)
    }
}

enum InMemorySessionRepositoryError: Error, LocalizedError, Sendable {
    case operationFailed(InMemorySessionRepositoryStore.Operation)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "InMemorySessionRepository operation \(operation) marked as failed."
        }
    }
}

extension SessionRepository {
    static func inMemory(
        store: InMemorySessionRepositoryStore
    ) -> SessionRepository {
        SessionRepository(
            performHandshake: {
                if await store.shouldFail(.performHandshake) {
                    throw InMemorySessionRepositoryError.operationFailed(.performHandshake)
                }
                return await store.handshake
            },
            fetchState: {
                if await store.shouldFail(.fetchState) {
                    throw InMemorySessionRepositoryError.operationFailed(.fetchState)
                }
                return await store.state
            },
            updateState: { update in
                if await store.shouldFail(.updateState) {
                    throw InMemorySessionRepositoryError.operationFailed(.updateState)
                }
                let newState = await store.apply(update: update)
                await store.setState(newState)
                return await store.state
            },
            checkCompatibility: {
                if await store.shouldFail(.checkCompatibility) {
                    throw InMemorySessionRepositoryError.operationFailed(.checkCompatibility)
                }
                return await store.compatibility
            }
        )
    }
}

extension InMemorySessionRepositoryStore {
    fileprivate func apply(update: SessionRepository.SessionUpdate) -> SessionState {
        var newState: SessionState = state
        if let speedLimits = update.speedLimits {
            if let download = speedLimits.download {
                newState.speedLimits.download = .init(
                    isEnabled: download.isEnabled,
                    kilobytesPerSecond: download.kilobytesPerSecond
                )
            }
            if let upload = speedLimits.upload {
                newState.speedLimits.upload = .init(
                    isEnabled: upload.isEnabled,
                    kilobytesPerSecond: upload.kilobytesPerSecond
                )
            }
            if let alternative = speedLimits.alternative {
                newState.speedLimits.alternative = .init(
                    isEnabled: alternative.isEnabled,
                    downloadKilobytesPerSecond: alternative.downloadKilobytesPerSecond,
                    uploadKilobytesPerSecond: alternative.uploadKilobytesPerSecond
                )
            }
        }

        if let queue = update.queue {
            if let downloadLimit = queue.downloadLimit {
                newState.queue.downloadLimit = .init(
                    isEnabled: downloadLimit.isEnabled,
                    count: downloadLimit.count
                )
            }
            if let seedLimit = queue.seedLimit {
                newState.queue.seedLimit = .init(
                    isEnabled: seedLimit.isEnabled,
                    count: seedLimit.count
                )
            }
            if let considerStalled = queue.considerStalled {
                newState.queue.considerStalled = considerStalled
            }
            if let stalledMinutes = queue.stalledMinutes {
                newState.queue.stalledMinutes = stalledMinutes
            }
        }

        if let seedRatioLimit = update.seedRatioLimit {
            newState.seedRatioLimit = .init(
                isEnabled: seedRatioLimit.isEnabled,
                value: seedRatioLimit.value
            )
        }

        return newState
    }
}
