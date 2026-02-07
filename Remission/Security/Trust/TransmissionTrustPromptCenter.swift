import Foundation

private actor OneShotTrustDecision {
    private var continuation: CheckedContinuation<TransmissionTrustDecision, Never>?

    init(_ continuation: CheckedContinuation<TransmissionTrustDecision, Never>) {
        self.continuation = continuation
    }

    func resume(with decision: TransmissionTrustDecision) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: decision)
    }
}

/// Coordinator that broadcasts TLS trust prompts to UI listeners.
///
/// Invariant: `makeHandler()` must never suspend forever if there are no observers.
/// If no observers are registered, the handler returns `.deny` to avoid hanging a URLSession challenge.
public actor TransmissionTrustPromptCenter {
    private var observers: [UUID: AsyncStream<TransmissionTrustPrompt>.Continuation] = [:]

    public init() {}

    public func observe() -> AsyncStream<TransmissionTrustPrompt> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    private func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func emit(_ prompt: TransmissionTrustPrompt) {
        for continuation in observers.values {
            continuation.yield(prompt)
        }
    }

    /// Creates a handler compatible with the trust evaluator.
    ///
    /// Nonisolated so call sites don't need to `await` just to obtain the closure.
    nonisolated public func makeHandler() -> TransmissionTrustDecisionHandler {
        { [weak self] challenge in
            guard let self else { return .deny }
            return await self.handle(challenge)
        }
    }

    private func handle(
        _ challenge: TransmissionTrustChallenge
    ) async -> TransmissionTrustDecision {
        let hasObservers = observers.isEmpty == false
        guard hasObservers else { return .deny }

        return await withCheckedContinuation { continuation in
            let oneShot = OneShotTrustDecision(continuation)
            let prompt = TransmissionTrustPrompt(
                challenge: challenge,
                resolver: { decision in
                    Task { await oneShot.resume(with: decision) }
                }
            )
            emit(prompt)
        }
    }
}

#if canImport(ComposableArchitecture)
    import ComposableArchitecture

    private enum TransmissionTrustPromptCenterKey: DependencyKey {
        static var liveValue: TransmissionTrustPromptCenter { TransmissionTrustPromptCenter() }
        static var previewValue: TransmissionTrustPromptCenter { TransmissionTrustPromptCenter() }
        static var testValue: TransmissionTrustPromptCenter { TransmissionTrustPromptCenter() }
    }

    extension DependencyValues {
        /// Provides access to the trust prompt center used to coordinate certificate trust decisions.
        public var transmissionTrustPromptCenter: TransmissionTrustPromptCenter {
            get { self[TransmissionTrustPromptCenterKey.self] }
            set { self[TransmissionTrustPromptCenterKey.self] = newValue }
        }
    }
#endif
