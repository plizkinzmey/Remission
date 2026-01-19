import Foundation

/// Представляет запрос на доверие сертификату и способ ответить на него.
public struct TransmissionTrustPrompt: Sendable, Equatable {
    public let challenge: TransmissionTrustChallenge
    private let resolver: @Sendable (TransmissionTrustDecision) -> Void

    init(
        challenge: TransmissionTrustChallenge,
        resolver: @escaping @Sendable (TransmissionTrustDecision) -> Void
    ) {
        self.challenge = challenge
        self.resolver = resolver
    }

    /// Завершает запрос решением пользователя.
    public func resolve(with decision: TransmissionTrustDecision) {
        resolver(decision)
    }
}

extension TransmissionTrustPrompt {
    /// Compares prompts by their underlying challenge identity.
    public static func == (lhs: TransmissionTrustPrompt, rhs: TransmissionTrustPrompt) -> Bool {
        lhs.challenge == rhs.challenge
    }
}

/// Координатор, выпускающий события запросов доверия и позволяющий асинхронно отвечать на них.
public final class TransmissionTrustPromptCenter: @unchecked Sendable {
    private let continuation: AsyncStream<TransmissionTrustPrompt>.Continuation
    public let prompts: AsyncStream<TransmissionTrustPrompt>

    public init() {
        var continuation: AsyncStream<TransmissionTrustPrompt>.Continuation!
        self.prompts = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    /// Создаёт хендлер, совместимый с TransmissionTrustEvaluator.
    public func makeHandler() -> TransmissionTrustDecisionHandler {
        { [weak self] challenge in
            guard let self else { return .deny }
            return await withCheckedContinuation { continuation in
                let prompt = TransmissionTrustPrompt(
                    challenge: challenge,
                    resolver: { decision in continuation.resume(returning: decision) }
                )
                self.continuation.yield(prompt)
            }
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
