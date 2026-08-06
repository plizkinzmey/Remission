// TransmissionAuth.swift
// Remission
//
// Authentication layer for Transmission RPC: Basic Auth + HTTP 409 session-id handshake.

import Foundation

/// Protocol for session ID storage (allows mocking in tests).
protocol SessionStoreProtocol: Sendable {
    func load() async -> String?
    func store(_ newValue: String?) async
}

/// Actor-based session ID storage.
actor SessionStore: SessionStoreProtocol {
    private var sessionID: String?

    func load() -> String? {
        sessionID
    }

    func store(_ newValue: String?) {
        sessionID = newValue
    }
}

/// Handles Transmission authentication: Basic Auth header + session-id handshake.
struct TransmissionAuth {
    let username: String?
    let password: String?
    let sessionStore: SessionStoreProtocol

    init(
        username: String?,
        password: String?,
        sessionStore: SessionStoreProtocol = SessionStore()
    ) {
        self.username = username
        self.password = password
        self.sessionStore = sessionStore
    }

    /// Builds the Basic Auth header value if credentials are present.
    func authorizationHeaderValue() -> String? {
        guard let username = username,
            let password = password,
            !username.isEmpty
        else { return nil }

        let credential = URLCredential(
            user: username,
            password: password,
            persistence: .forSession
        )
        guard let user = credential.user,
            let secret = credential.password
        else { return nil }

        let credentialsData = Data("\(user):\(secret)".utf8)
        let base64Credentials = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }

    /// Applies authentication headers (Basic Auth + session-id) to a request.
    func applyHeaders(to request: inout URLRequest) async {
        if let authHeader = authorizationHeaderValue() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        if let sessionID = await sessionStore.load() {
            request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        }
    }

    /// Handles HTTP 409 session conflict: extracts session-id from response and retries.
    /// - Returns: `true` if request should be retried with new session-id, `false` if conflict is fatal.
    func handleSessionConflict(
        response: HTTPURLResponse,
        request: inout URLRequest
    ) async throws -> Bool {
        guard response.statusCode == 409 else { return false }

        guard let sessionID = response.value(forHTTPHeaderField: "X-Transmission-Session-Id"),
            !sessionID.isEmpty
        else {
            throw APIError.sessionConflict
        }

        await sessionStore.store(sessionID)
        request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        await applyHeaders(to: &request)
        return true
    }
}
