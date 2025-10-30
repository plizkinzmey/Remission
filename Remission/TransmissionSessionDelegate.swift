import Foundation

private struct SendableSecTrust: @unchecked Sendable {
    let value: SecTrust
}

private struct CompletionWrapper: @unchecked Sendable {
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
        Task { @MainActor in
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
