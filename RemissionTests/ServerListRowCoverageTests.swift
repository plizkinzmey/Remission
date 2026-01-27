import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Server List Row Coverage")
@MainActor
struct ServerListRowCoverageTests {
    @Test
    func serverRowRendersConnectedAndFailedStates() {
        let store = Store(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }
        let view = ServerListView(store: store)

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

        _ = view.serverRow(ServerConfig.sample, status: connected)

        var failed = ServerListReducer.ConnectionStatus()
        failed.phase = .failed("Connection failed")
        _ = view.serverRow(ServerConfig.sample, status: failed)
    }

    @Test
    func connectionStatusChipDescriptorCoversAllPhases() {
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
