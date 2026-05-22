import ComposableArchitecture
import SwiftUI
import XCTest

@testable import Remission

@MainActor
final class ServerListRowCoverageTests: XCTestCase {
    func testServerConnectionInfoDescriptorBuildsHoverHelp() {
        let handshake = TransmissionHandshakeResult(
            sessionID: "session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )

        let descriptor = ServerConnectionInfoDescriptor(
            server: .previewLocalHTTP,
            handshake: handshake
        )

        XCTAssertEqual(descriptor.transport, "HTTP")
        XCTAssertEqual(
            descriptor.helpText,
            "Transmission 4.0.3\nRPC v17\nLegacy RPC\nHTTP"
        )
    }

    func testServerRowRendersConnectedAndFailedStates() {
        let handshake = TransmissionHandshakeResult(
            sessionID: "session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )

        var connected = ServerListReducer.ConnectionStatus()
        connected.phase = .connected(handshake)
        connected.storageSummary = StorageSummary(totalBytes: 10_000, freeBytes: 4_000)

        _ = ServerRowView(
            server: ServerConfig.sample,
            status: connected,
            onTap: {},
            onEdit: {},
            onDelete: {}
        )

        var failed = ServerListReducer.ConnectionStatus()
        failed.phase = .failed("Connection failed")
        _ = ServerRowView(
            server: ServerConfig.sample,
            status: failed,
            onTap: {},
            onEdit: {},
            onDelete: {}
        )
    }
    func testConnectionStatusChipDescriptorCoversAllPhases() {
        _ = ConnectionStatusChipDescriptor(phase: .idle)
        _ = ConnectionStatusChipDescriptor(phase: .probing)
        _ = ConnectionStatusChipDescriptor(
            phase: .connected(
                TransmissionHandshakeResult(
                    sessionID: "session",
                    rpcVersion: 17,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: nil,
                    isCompatible: true
                )
            )
        )
        _ = ConnectionStatusChipDescriptor(phase: .failed("Failed"))
    }
}
