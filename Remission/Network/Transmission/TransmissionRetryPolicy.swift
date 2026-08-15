// TransmissionRetryPolicy.swift
// Remission
//
// Retry policy for Transmission RPC requests: exponential backoff, error classification, JSON-RPC fallback.

import Foundation

/// Configuration for retry behavior.
struct TransmissionRetryConfig: Sendable {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let retryDelay: TimeInterval  // legacy field used for backoff calculation

    static let `default` = TransmissionRetryConfig(
        maxRetries: 3,
        baseDelay: 1.0,
        retryDelay: 1.0
    )
}

/// Errors that can be retried.
enum TransmissionRetryError: Error, Equatable {
    case network(URLError)
    case sessionConflict
    case transientServerError(Int)  // 5xx errors
}

/// Result of retry decision including fallback.
enum RetryDecision: Error, Sendable {
    case retry(after: Duration)
    case fail(TransmissionRetryError)
    case fallbackToLegacy(reason: String)
}

/// Handles retry logic for Transmission RPC requests.
struct TransmissionRetryPolicy {
    let config: TransmissionRetryConfig
    let clock: any Clock<Duration>

    init(
        config: TransmissionRetryConfig = .default,
        clock: any Clock<Duration>
    ) {
        self.config = config
        self.clock = clock
    }

    /// Execute a request with retry logic.
    /// The `operation` closure should throw `TransmissionRetryError` for retryable errors.
    /// Can also throw `RetryDecision.fallbackToLegacy` for JSON-RPC → Legacy fallback.
    func execute<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var state = RetryState(maxRetries: config.maxRetries)

        while true {
            do {
                return try await operation()
            } catch let retryError as TransmissionRetryError {
                try await handle(retryError, state: &state)
            } catch let urlError as URLError {
                try await handle(urlError, state: &state)
            } catch let apiError as APIError {
                if let fallbackReason = fallbackReasonFromAPIError(apiError) {
                    throw RetryDecision.fallbackToLegacy(reason: fallbackReason)
                }
                throw apiError
            } catch let decision as RetryDecision {
                throw decision
            } catch {
                throw APIError.unknown(details: error.localizedDescription)
            }
        }
    }

    private struct RetryState {
        var remainingRetries: Int
        var retryAttempt = 0

        init(maxRetries: Int) {
            remainingRetries = maxRetries
        }
    }

    private func handle(
        _ error: TransmissionRetryError,
        state: inout RetryState
    ) async throws {
        switch error {
        case .network(let urlError):
            guard shouldRetryURLError(urlError) else {
                throw APIError.mapURLError(urlError)
            }
            try await waitForRetry(
                state: &state,
                exhaustedError: APIError.mapURLError(urlError)
            )
        case .sessionConflict:
            throw APIError.sessionConflict
        case .transientServerError(let statusCode):
            let exhaustedError = APIError.unknown(
                details: "Transient server error (\(statusCode)) after max retries")
            try await waitForRetry(state: &state, exhaustedError: exhaustedError)
        }
    }

    private func handle(
        _ error: URLError,
        state: inout RetryState
    ) async throws {
        guard shouldRetryURLError(error) else {
            throw APIError.mapURLError(error)
        }
        try await waitForRetry(
            state: &state,
            exhaustedError: APIError.mapURLError(error)
        )
    }

    private func waitForRetry(
        state: inout RetryState,
        exhaustedError: APIError
    ) async throws {
        guard state.remainingRetries > 0 else {
            throw exhaustedError
        }
        state.remainingRetries -= 1
        let delay = retryDelay(for: state.retryAttempt)
        state.retryAttempt += 1
        try await clock.sleep(for: delay)
    }

    /// Determines if an APIError should trigger JSON-RPC → Legacy fallback.
    private func fallbackReasonFromAPIError(_ error: APIError) -> String? {
        switch error {
        case .decodingFailed(let details):
            let lower = details.lowercased()
            let protocolMismatchSignals = [
                "missing result in json-rpc response",
                "missing or invalid rpc-version/rpc_version in session-get response",
                "unsupported jsonrpc version",
                "invalid json-rpc response"
            ]
            if protocolMismatchSignals.contains(where: { lower.contains($0) }) {
                return details
            }
            return nil
        case .unknown(let details):
            let lower = details.lowercased()
            if lower.contains("method not found") || lower.contains("json-rpc") {
                return details
            }
            return nil
        default:
            return nil
        }
    }

    /// Determines if a URL error should trigger a retry.
    private func shouldRetryURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet:
            return false  // No point retrying if there's no internet
        case .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed,
            .secureConnectionFailed,
            .cannotLoadFromNetwork:
            return true
        default:
            return false
        }
    }

    /// Computes exponential backoff delay for a given attempt.
    private func retryDelay(for attempt: Int) -> Duration {
        guard config.retryDelay > 0 else { return .seconds(0) }
        let exponential = config.retryDelay * pow(2.0, Double(attempt))
        let clamped = min(max(exponential, 0), TimeInterval(Int.max))
        return .milliseconds(Int(clamped * 1_000))
    }
}
