import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server List Management Tests")
@MainActor
struct ServerListManagementTests {

    @Test("Add button открывает форму добавления")
    func testAddButtonTapped() async {
        // Проверяем, что addButtonTapped открывает форму и помечает onboarding показанным.
        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        }

        await store.send(.addButtonTapped) {
            $0.hasPresentedInitialOnboarding = true
            $0.serverForm = ServerFormReducer.State(mode: .add)
        }
    }

    @Test("Edit button открывает форму редактирования")
    func testEditButtonTapped() async {
        // Проверяем, что editButtonTapped открывает форму редактирования выбранного сервера.
        let server = ServerConfig.previewLocalHTTP
        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        }

        await store.send(.editButtonTapped(server.id)) {
            $0.serverForm = ServerFormReducer.State(mode: .edit(server))
        }
    }

    @Test("Удаление сервера отправляет запрос в репозиторий")
    func testDeleteServerFlow() async {
        // Проверяем полный сценарий: подтверждение удаления -> вызов репозитория -> обновление списка.
        let server = ServerConfig.previewLocalHTTP

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.credentialsRepository.delete = { @Sendable _ in }
            $0.httpWarningPreferencesStore.reset = { @Sendable _ in }
            $0.transmissionTrustStoreClient.deleteFingerprint = { @Sendable _ in }
            $0.serverConfigRepository.delete = { @Sendable _ in [] }
            $0.onboardingProgressRepository.hasCompletedOnboarding = { @Sendable in true }
        }
        store.exhaustivity = .off

        await store.send(.deleteButtonTapped(server.id)) {
            $0.pendingDeletion = server
            $0.deleteConfirmation = AlertFactory.confirmationDialog(
                title: String(format: L10n.tr("serverList.alert.delete.title"), server.name),
                message: L10n.tr("serverList.alert.delete.message"),
                confirmAction: .confirm,
                cancelAction: .cancel
            )
        }

        await store.send(.deleteConfirmation(.presented(.confirm))) {
            $0.pendingDeletion = nil
            $0.deleteConfirmation = nil
        }

        await store.receive(.serverRepositoryResponse(.success([]))) {
            $0.isLoading = false
            $0.servers = []
        }
    }

    @Test("Создание сервера добавляет в список и запускает probe")
    func testServerFormDidCreate() async {
        // Проверяем, что didCreate добавляет сервер и запускает connectionProbe.
        let server = ServerConfig.previewLocalHTTP

        let store = TestStore(initialState: ServerListReducer.State()) {
            ServerListReducer()
        }
        store.exhaustivity = .off

        await store.send(.serverForm(.presented(.delegate(.didCreate(server))))) {
            $0.servers.append(server)
            $0.serverForm = nil
        }

        await store.receive(.delegate(.serverCreated(server)))
        await store.receive(.connectionProbeRequested(server.id))
    }
}
