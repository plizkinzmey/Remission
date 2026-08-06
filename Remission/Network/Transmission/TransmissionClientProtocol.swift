// TransmissionClientProtocol.swift
// Remission
//
// Protocol for Transmission RPC client.
// Defines the contract for all methods needed for MVP (session-get, torrent-get/add/start/stop/remove).

import Foundation

/// Result of Transmission RPC handshake, containing connection metadata.
public struct TransmissionHandshakeResult: Equatable, Sendable {
    public let sessionID: String?
    public let rpcVersion: Int
    public let minimumSupportedRpcVersion: Int
    public let serverVersionDescription: String?
    public let rpcVersionSemver: String?
    public let rpcMode: TransmissionRPCMode
    public let isCompatible: Bool

    public init(
        sessionID: String?,
        rpcVersion: Int,
        minimumSupportedRpcVersion: Int,
        serverVersionDescription: String?,
        rpcVersionSemver: String? = nil,
        rpcMode: TransmissionRPCMode = .legacy,
        isCompatible: Bool
    ) {
        self.sessionID = sessionID
        self.rpcVersion = rpcVersion
        self.minimumSupportedRpcVersion = minimumSupportedRpcVersion
        self.serverVersionDescription = serverVersionDescription
        self.rpcVersionSemver = rpcVersionSemver
        self.rpcMode = rpcMode
        self.isCompatible = isCompatible
    }
}

/// Protocol for client interacting with Transmission RPC API.
/// Concrete implementation using URLSession is injected via DI.
public protocol TransmissionClientProtocol: Sendable {
    typealias TorrentIDs = [Int]
    typealias ClientResult = TransmissionResponse

    /// Get current session info and Transmission version.
    /// Used during handshake to verify version compatibility (minimum 3.0).
    func sessionGet() async throws -> ClientResult

    /// Set session parameters (e.g., speed limits).
    func sessionSet(arguments: AnyCodable) async throws -> ClientResult

    /// Get session statistics (active torrents, speeds, counters).
    func sessionStats() async throws -> ClientResult

    /// Get free space at given path (`free-space`).
    func freeSpace(path: String) async throws -> ClientResult

    /// Get torrent information.
    /// - Parameters:
    ///   - ids: Optional array of torrent IDs for filtering.
    ///   - fields: Optional array of fields to optimize response.
    func torrentGet(ids: TorrentIDs?, fields: [String]?) async throws -> ClientResult

    /// Add new torrent from file, magnet link, or URL.
    /// - Parameters:
    ///   - filename: Path to file, URL, or magnet link. Optional if `metainfo` provided.
    ///   - metainfo: Base64 raw `.torrent` file data. Optional if `filename` provided.
    ///   - downloadDir: Optional download directory.
    ///   - paused: Whether to start torrent paused.
    ///   - labels: Optional tags for torrent.
    func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> ClientResult

    /// Start one or more torrents.
    func torrentStart(ids: TorrentIDs) async throws -> ClientResult

    /// Stop one or more torrents.
    func torrentStop(ids: TorrentIDs) async throws -> ClientResult

    /// Remove one or more torrents.
    /// - Parameters:
    ///   - ids: Array of torrent IDs.
    ///   - deleteLocalData: Whether to delete local torrent files.
    func torrentRemove(ids: TorrentIDs, deleteLocalData: Bool?) async throws -> ClientResult

    /// Set parameters for one or more torrents (priorities, limits).
    func torrentSet(ids: TorrentIDs, arguments: AnyCodable) async throws -> ClientResult

    /// Verify torrent integrity (long-running operation).
    func torrentVerify(ids: TorrentIDs) async throws -> ClientResult

    /// Checks server version compatibility with minimum required Transmission version (3.0+, RPC v14).
    /// - Returns: A tuple containing compatibility status and the RPC version number.
    /// - Throws: `APIError` if unable to parse version information.
    func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int)

    /// Performs full handshake with Transmission server:
    /// obtains session-id (if needed) and verifies version compatibility.
    /// - Returns: `TransmissionHandshakeResult` with detailed information.
    /// - Throws: `APIError.sessionConflict`, `APIError.decodingFailed` and other network layer errors.
    func performHandshake() async throws -> TransmissionHandshakeResult

    /// Registers trust decision handler for self-signed / untrusted certificates.
    func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler)
}
