import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server List Feature Tests")
@MainActor
struct ServerListFeatureTests {

    @Test("Initial load with no servers")
    func testTask_InitialLoad_Empty() async {
        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConfigRepository.load = { @Sendable in [] }
            $0.onboardingProgressRepository.hasCompletedOnboarding = { @Sendable in true }
        }

        await store.send(ServerListReducer.Action.task) {
            $0.isLoading = true
        }

        await store.receive(ServerListReducer.Action.serverRepositoryResponse(.success([]))) {
            $0.isLoading = false
            $0.servers = []
        }
    }

    @Test("Initial load with servers and auto-selection")
    func testTask_InitialLoad_WithServers() async {
        let server = ServerConfig.sample
        let handshake = TransmissionHandshakeResult(
            sessionID: "test-session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 1,
            serverVersionDescription: "4.0.0",
            isCompatible: true
        )
        let probeResult = ServerConnectionProbe.Result(handshake: handshake)

        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConfigRepository.load = { @Sendable in [server] }
            $0.serverConnectionProbe.run = { @Sendable _, _ in probeResult }
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in .previewValue }
            $0.credentialsRepository.load = { @Sendable _ in
                TransmissionServerCredentials(
                    key: server.credentialsKey!,
                    password: "password"
                )
            }
        }

        store.exhaustivity = .off

        await store.send(ServerListReducer.Action.task)

        await store.receive(ServerListReducer.Action.serverRepositoryResponse(.success([server]))) {
            $0.servers = [server]
            $0.hasAutoSelectedSingleServer = true
        }

        await store.receive(ServerListReducer.Action.connectionProbeRequested(server.id))
        await store.receive(ServerListReducer.Action.delegate(.serverSelected(server)))

        await store.receive(
            ServerListReducer.Action.connectionProbeResponse(server.id, .success(probeResult))
        ) {
            $0.connectionStatuses[server.id] = ServerListReducer.ConnectionStatus(
                phase: .connected(handshake)
            )
        }

        await store.receive(ServerListReducer.Action.storageRequested(server.id))
    }

    @Test("Add button tapped")
    func testAddButtonTapped() async {
        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        }

        await store.send(ServerListReducer.Action.addButtonTapped) {
            $0.hasPresentedInitialOnboarding = true
            $0.serverForm = ServerFormReducer.State(mode: .add)
        }
    }

    @Test("Delete server flow")
    func testDeleteServerFlow() async {
        let server = ServerConfig.sample
        let store = TestStore(
            initialState: ServerListReducer.State(
                servers: [server]
            )
        ) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConfigRepository.delete = { @Sendable _ in [] }
            $0.credentialsRepository.delete = { @Sendable _ in }
            $0.httpWarningPreferencesStore.reset = { @Sendable _ in }
            $0.transmissionTrustStoreClient.deleteFingerprint = { @Sendable _ in }
            $0.onboardingProgressRepository.hasCompletedOnboarding = { @Sendable in true }
        }

        await store.send(ServerListReducer.Action.deleteButtonTapped(server.id)) {
            $0.pendingDeletion = server
            $0.deleteConfirmation = AlertFactory.confirmationDialog(
                title: String(format: L10n.tr("serverList.alert.delete.title"), server.name),
                message: L10n.tr("serverList.alert.delete.message"),
                confirmAction: ServerListReducer.DeleteConfirmationAction.confirm,
                cancelAction: ServerListReducer.DeleteConfirmationAction.cancel
            )
        }

        await store.send(
            ServerListReducer.Action.deleteConfirmation(
                .presented(ServerListReducer.DeleteConfirmationAction.confirm))
        ) {
            $0.pendingDeletion = nil
            $0.deleteConfirmation = nil
        }

        await store.receive(ServerListReducer.Action.serverRepositoryResponse(.success([]))) {
            $0.servers = []
            // Onboarding should NOT be triggered because hasCompletedOnboarding is true
            $0.serverForm = nil
            $0.hasPresentedInitialOnboarding = false
        }
    }
}

extension ServerConfig {
    static var sample: ServerConfig {
        ServerConfig(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test Server",
            connection: .init(host: "192.168.1.1", port: 9091),
            security: .http,
            authentication: .init(username: "admin")
        )
    }
}
