import Foundation

private struct SendableSecTrust: @unchecked Sendable {
    // Safety invariant:
    // - `SecTrust` is treated as immutable after creation by the system.
    // - We only pass it across concurrency boundaries for evaluation; we do not mutate it.
    let value: SecTrust
}

private struct CompletionWrapper: @unchecked Sendable {
    // Safety invariant:
    // - The wrapped completion handler is invoked from a Task (potentially off-main).
    // - URLSession requires it to be called exactly once per challenge; our code path satisfies that.
    // - We never share/mutate captured state through this wrapper; it is a thin transport container.
    let handler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

    init(_ handler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        self.handler = handler
    }
}

final class TransmissionSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let trustEvaluator: TransmissionTrustEvaluator

    init(trustEvaluator: TransmissionTrustEvaluator) {
        self.trustEvaluator = trustEvaluator
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let wrappedTrust = SendableSecTrust(value: serverTrust)
        let completion = CompletionWrapper(completionHandler)
        Task {
            let outcome = await trustEvaluator.evaluate(serverTrust: wrappedTrust.value)
            switch outcome {
            case .useCredential(let credential):
                completion.handler(.useCredential, credential)
            case .performDefaultHandling:
                completion.handler(.performDefaultHandling, nil)
            case .cancel:
                completion.handler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}
