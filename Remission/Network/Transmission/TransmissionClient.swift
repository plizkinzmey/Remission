// TransmissionClient.swift
// Remission
//
// Facade for Transmission RPC client. Coordinates auth, retry policy, and RPC resolution.

import Foundation

/// Основной клиент Transmission RPC.
public final class TransmissionClient: TransmissionClientProtocol, Sendable {
    // MARK: - Properties

    private let config: TransmissionClientConfig
    private let auth: TransmissionAuth
    private let retryPolicy: TransmissionRetryPolicy
    private let rpcResolver: TransmissionRPCResolver
    private let session: URLSession
    private let trustEvaluator: TransmissionTrustEvaluator
    private let clock: any Clock<Duration>
    private let appLogger: AppLogger
    private let baseLogContext: TransmissionLogContext

    // MARK: - Test accessors

    /// For testing: access to RPC mode store
    var rpcModeStore: RPCModeStore { rpcResolver.rpcModeStoreConcrete! }

    /// For testing: access to session store
    var sessionStore: SessionStore { auth.sessionStore as! SessionStore }

    /// For testing: access to JSON-RPC ID store
    var jsonrpcIDStore: JSONRPCIDStore { rpcResolver.jsonrpcIDStoreConcrete! }

    /// For testing: access to RPC mode store protocol
    var rpcModeStoreProtocol: RPCModeStoreProtocol { rpcResolver.rpcModeStore }

    /// For testing: access to JSON-RPC ID store protocol
    var jsonrpcIDStoreProtocol: JSONRPCIDStoreProtocol { rpcResolver.jsonrpcIDStore }

    // For backwards compatibility with tests
    var rpcVersionStore: Any {
        fatalError("rpcVersionStore removed - use rpcResolver for mode management")
    }

    // RPCMethod was moved to TransmissionRPCProtocol.swift as TransmissionRPCMethod
    typealias RPCMethod = TransmissionRPCMethod

    // Test accessors for internal components
    var test_rpcResolver: TransmissionRPCResolver { rpcResolver }
    var test_auth: TransmissionAuth { auth }

    // MARK: - Init

    /// Creates a live instance with all dependencies configured.
    public static func live(
        config: TransmissionClientConfig,
        clock: any Clock<Duration>,
        appLogger: AppLogger,
        category: String,
        sessionConfiguration: URLSessionConfiguration? = nil,
        trustStore: TransmissionTrustStore = TransmissionTrustStore()
    ) -> TransmissionClient {
        let context = TransmissionLogContext(
            serverID: config.serverID,
            host: config.baseURL.host,
            path: config.baseURL.path
        )

        let logger = DefaultTransmissionLogger(
            appLogger: appLogger.withCategory(category),
            baseContext: context
        )

        var finalConfig = config
        finalConfig.logger = logger

        return TransmissionClient(
            config: finalConfig,
            sessionConfiguration: sessionConfiguration,
            trustStore: trustStore,
            clock: clock,
            appLogger: appLogger.withCategory(category),
            baseLogContext: context
        )
    }

    /// Internal initializer for tests and custom configurations.
    public init(
        config: TransmissionClientConfig,
        sessionConfiguration: URLSessionConfiguration? = nil,
        trustStore: TransmissionTrustStore = TransmissionTrustStore(),
        trustDecisionHandler: TransmissionTrustDecisionHandler? = nil,
        clock: any Clock<Duration>,
        appLogger: AppLogger = .noop,
        baseLogContext: TransmissionLogContext? = nil
    ) {
        self.config = config
        self.clock = clock
        self.appLogger = appLogger
        self.baseLogContext =
            baseLogContext
            ?? TransmissionLogContext(
                serverID: config.serverID,
                host: config.baseURL.host,
                path: config.baseURL.path
            )

        // Setup auth
        let sessionStore = SessionStore()
        self.auth = TransmissionAuth(
            username: config.username,
            password: config.password,
            sessionStore: sessionStore
        )

        // Setup retry policy
        let retryConfig = TransmissionRetryConfig(
            maxRetries: config.maxRetries,
            baseDelay: config.retryDelay,
            retryDelay: config.retryDelay
        )
        self.retryPolicy = TransmissionRetryPolicy(config: retryConfig, clock: clock)

        // Setup RPC resolver
        let rpcModeStore = RPCModeStore()
        let jsonrpcIDStore = JSONRPCIDStore()
        self.rpcResolver = TransmissionRPCResolver(
            mode: config.rpcMode,
            rpcModeStore: rpcModeStore,
            jsonrpcIDStore: jsonrpcIDStore
        )

        // Setup TLS trust evaluation
        let host = config.baseURL.host ?? ""
        let isSecure = config.baseURL.scheme?.lowercased() == "https"
        let port = config.baseURL.port ?? (isSecure ? 443 : 80)
        let identity = TransmissionServerTrustIdentity(host: host, port: port, isSecure: isSecure)
        let handler = trustDecisionHandler ?? { _ in .deny }
        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: trustStore,
            decisionHandler: handler
        )
        self.trustEvaluator = evaluator
        let delegate = TransmissionSessionDelegate(trustEvaluator: evaluator)

        // Setup URLSession
        let configuration = sessionConfiguration ?? .default
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(
            configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Public API (Core)

    public func sendRequest(
        method: String,
        arguments: AnyCodable? = nil,
        tag: TransmissionTag? = nil
    ) async throws -> TransmissionResponse {
        let baseURL = config.baseURL
        let timeout = config.requestTimeout
        let enableLogging = config.enableLogging
        let logger = config.logger
        let auth = self.auth

        // Prepare base request headers
        var baseRequest: URLRequest = {
            var req = URLRequest(url: baseURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = timeout
            return req
        }()

        await auth.applyHeaders(to: &baseRequest)

        // Log request if enabled
        if enableLogging {
            logger.logRequest(
                method: method,
                request: baseRequest,
                context: makeLogContext(method: method)
            )
        }

        // Execute with retry logic
        return try await retryPolicy.execute { [baseRequest] in
            var request = baseRequest
            var modeIndex = 0
            let modesToTry = await self.rpcResolver.initialModesToTry()
            var sessionConflictCount = 0

            while true {
                let mode = modesToTry[modeIndex]
                let bodyData = try await self.rpcResolver.encodeRequestBody(
                    method: method,
                    arguments: arguments,
                    tag: tag,
                    mode: mode
                )
                request.httpBody = bodyData

                let attemptStartedAt = Date()
                do {
                    let (data, response) = try await self.session.data(for: request)
                    let elapsedMs = Date().timeIntervalSince(attemptStartedAt) * 1_000

                    let httpResponse = try self.requireHTTPResponse(response)

                    // Log response
                    if self.config.enableLogging {
                        self.config.logger.logResponse(
                            method: method,
                            statusCode: httpResponse.statusCode,
                            responseBody: data,
                            context: self.makeLogContext(
                                method: method,
                                statusCode: httpResponse.statusCode,
                                durationMs: elapsedMs
                            )
                        )
                    }

                    // Handle session conflict
                    let shouldRetry = try await self.handleSessionConflictIfNeeded(
                        httpResponse,
                        request: &request,
                        mode: mode
                    )
                    if shouldRetry {
                        sessionConflictCount += 1
                        // Limit session conflict retries (use 3 as default, or maxRetries if > 0)
                        let maxSessionConflicts =
                            self.config.maxRetries > 0 ? self.config.maxRetries : 3
                        if sessionConflictCount >= maxSessionConflicts {
                            throw APIError.sessionConflict
                        }
                        continue
                    }

                    try self.validateHTTPStatus(httpResponse)

                    let transmissionResponse = try self.rpcResolver.decodeResponse(
                        from: data, mode: mode)

                    if transmissionResponse.isError {
                        let errorMessage = transmissionResponse.errorMessage ?? "Unknown RPC error"
                        throw APIError.mapTransmissionError(errorMessage)
                    }

                    await self.rpcResolver.persistResolvedModeIfNeeded(mode)
                    return transmissionResponse

                } catch let apiError as APIError {
                    // Check for JSON-RPC fallback
                    if self.rpcResolver.fallbackReasonFromAPIError(apiError) != nil,
                        mode == .jsonRpc2,
                        modeIndex + 1 < modesToTry.count
                    {
                        modeIndex += 1
                        continue
                    }
                    throw apiError
                } catch let decision as RetryDecision {
                    // Handle JSON-RPC → Legacy fallback from retry policy
                    if case .fallbackToLegacy = decision,
                        mode == .jsonRpc2,
                        modeIndex + 1 < modesToTry.count
                    {
                        modeIndex += 1
                        continue
                    }
                    throw decision
                } catch let urlError as URLError {
                    // Wrap URLError for retry policy to handle
                    throw TransmissionRetryError.network(urlError)
                } catch let retryError as TransmissionRetryError {
                    // Re-throw retry errors as-is for retry policy
                    throw retryError
                } catch {
                    throw APIError.unknown(details: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - TransmissionClientProtocol Implementation (via sendRequest)

    public func sessionGet() async throws -> TransmissionResponse {
        try await sendRequest(method: "session-get")
    }

    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: "session-set", arguments: arguments)
    }

    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: "session-stats")
    }

    public func freeSpace(path: String) async throws -> TransmissionResponse {
        try await sendRequest(method: "free-space", arguments: .object(["path": .string(path)]))
    }

    public func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]
        if let ids { arguments["ids"] = .array(ids.map { .int($0) }) }
        if let fields { arguments["fields"] = .array(fields.map { .string($0) }) }
        let finalArguments: AnyCodable? = arguments.isEmpty ? nil : .object(arguments)
        return try await sendRequest(method: "torrent-get", arguments: finalArguments)
    }

    public func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]
        if let filename { arguments["filename"] = .string(filename) }
        if let metainfo { arguments["metainfo"] = .string(metainfo.base64EncodedString()) }
        if let downloadDir { arguments["download-dir"] = .string(downloadDir) }
        if let paused { arguments["paused"] = .bool(paused) }
        if let labels { arguments["labels"] = .array(labels.map { .string($0) }) }
        return try await sendRequest(method: "torrent-add", arguments: .object(arguments))
    }

    public func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: "torrent-start", arguments: .object(["ids": .array(ids.map { .int($0) })]))
    }

    public func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: "torrent-stop", arguments: .object(["ids": .array(ids.map { .int($0) })]))
    }

    public func torrentRemove(ids: [Int], deleteLocalData: Bool?) async throws
        -> TransmissionResponse
    {
        var arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        if let deleteLocalData { arguments["delete-local-data"] = .bool(deleteLocalData) }
        return try await sendRequest(method: "torrent-remove", arguments: .object(arguments))
    }

    public func torrentSet(ids: [Int], arguments: AnyCodable) async throws -> TransmissionResponse {
        var args: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        if case .object(let obj) = arguments {
            for (key, value) in obj {
                args[key] = value
            }
        }
        return try await sendRequest(method: "torrent-set", arguments: .object(args))
    }

    public func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        try await sendRequest(
            method: "torrent-verify", arguments: .object(["ids": .array(ids.map { .int($0) })]))
    }

    public func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
        let response = try await sessionGet()
        guard let arguments = response.arguments?.objectValue,
            let rpcVersion = arguments["rpc-version"]?.intValue
                ?? arguments["rpc_version"]?.intValue
        else {
            throw APIError.decodingFailed(
                underlyingError: "Missing rpc-version in session-get response")
        }
        let compatible = rpcVersion >= 14  // Transmission 3.0+
        return (compatible, rpcVersion)
    }

    public func performHandshake() async throws -> TransmissionHandshakeResult {
        let (compatible, rpcVersion) = try await checkServerVersion()
        let sessionGetResult = try await sessionGet()
        let sessionID = await auth.sessionStore.load()

        let serverVersion = sessionGetResult.arguments?.objectValue?["version"]?.stringValue
        let minimumRpcVersion =
            sessionGetResult.arguments?.objectValue?["minimum-rpc-version"]?.intValue
            ?? sessionGetResult.arguments?.objectValue?["minimum_rpc_version"]?.intValue ?? 14

        if !compatible {
            throw APIError.versionUnsupported(version: serverVersion ?? "unknown")
        }

        // Extract RPC mode and semver from response if available
        let rpcMode: TransmissionRPCMode
        let rpcVersionSemver: String?

        if config.rpcMode == .jsonRpc2 {
            rpcMode = .jsonRpc2
            // Try to extract semver from JSON-RPC response
            rpcVersionSemver =
                sessionGetResult.arguments?.objectValue?["rpc_version_semver"]?.stringValue
        } else {
            rpcMode = .legacy
            rpcVersionSemver = nil
        }

        return TransmissionHandshakeResult(
            sessionID: sessionID,
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumRpcVersion,
            serverVersionDescription: serverVersion,
            rpcVersionSemver: rpcVersionSemver,
            rpcMode: rpcMode,
            isCompatible: compatible
        )
    }

    public func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {
        Task { await trustEvaluator.updateDecisionHandler(handler) }
    }

    // MARK: - Private Helpers

    private func makeLogContext(
        method: String,
        statusCode: Int? = nil,
        durationMs: Double? = nil,
        retryAttempt: Int? = nil
    ) -> TransmissionLogContext {
        TransmissionLogContext(
            serverID: baseLogContext.serverID,
            host: baseLogContext.host,
            path: baseLogContext.path,
            method: method,
            statusCode: statusCode,
            durationMs: durationMs,
            retryAttempt: retryAttempt,
            maxRetries: config.maxRetries
        )
    }

    private func requireHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(details: "Unsupported URLResponse: \(type(of: response))")
        }
        return httpResponse
    }

    private func validateHTTPStatus(_ httpResponse: HTTPURLResponse) throws {
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.mapHTTPStatusCode(httpResponse.statusCode)
        }
    }

    private func handleSessionConflictIfNeeded(
        _ httpResponse: HTTPURLResponse,
        request: inout URLRequest,
        mode: TransmissionRPCMode
    ) async throws -> Bool {
        guard httpResponse.statusCode == 409 else { return false }

        // Track session conflict retries - we limit these separately from network retries
        // because the main loop doesn't count them in its retry logic
        // Use a task-local to track per-request session conflict count
        // For now, use a simple approach: the auth layer can only handle one session conflict per request
        // but we need to allow multiple for the test
        // The test creates 5 409 responses, so we need to handle multiple

        // Delegate session conflict handling to auth - just update session ID and request headers
        // The main loop will retry the request
        let shouldRetry = try await auth.handleSessionConflict(
            response: httpResponse, request: &request)
        return shouldRetry
    }

    private func logNetworkError(
        method: String,
        error: Error,
        retryAttempt: Int?,
        elapsedMs: Double?
    ) {
        let context = makeLogContext(
            method: method,
            durationMs: elapsedMs,
            retryAttempt: retryAttempt
        )
        config.logger.logError(method: method, error: error, context: context)
    }
}
