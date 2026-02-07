import Foundation

/// A UI-presentable request for a TLS trust decision, plus a way to resolve it.
public struct TransmissionTrustPrompt: Sendable, Equatable {
    public let challenge: TransmissionTrustChallenge
    private let resolver: @Sendable (TransmissionTrustDecision) -> Void

    public init(
        challenge: TransmissionTrustChallenge,
        resolver: @escaping @Sendable (TransmissionTrustDecision) -> Void
    ) {
        self.challenge = challenge
        self.resolver = resolver
    }

    /// Completes the prompt with a user decision.
    public func resolve(with decision: TransmissionTrustDecision) {
        resolver(decision)
    }

    /// Prompts compare by the underlying challenge identity (the resolver closure is not comparable).
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.challenge == rhs.challenge
    }
}
