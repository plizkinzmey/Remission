import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Form Feature Tests")
@MainActor
struct ServerFormFeatureTests {

    @Test("Успешное сохранение нового сервера")
    func testSaveAddSuccess() async {
        // Проверяем, что сохранение в режиме add пишет credentials, сохраняет конфиг
        // и уведомляет delegate о создании.
        let recorder = SaveRecorder()
        let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        var state = ServerFormReducer.State(mode: .add)
        state.serverConfig.form.name = "Home"
        state.serverConfig.form.host = "nas.local"
        state.serverConfig.form.port = "9091"
        state.serverConfig.form.path = "/transmission/rpc"
        state.serverConfig.form.username = "admin"
        state.serverConfig.form.password = "secret"
        state.serverConfig.verifiedSubmission = ServerSubmissionContext(
            server: state.serverConfig.form.makeServerConfig(id: fixedID, createdAt: fixedDate),
            password: "secret"
        )

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.credentialsRepository.save = { @Sendable credentials in
                recorder.recordCredentials(credentials)
            }
            $0.serverConfigRepository.upsert = { @Sendable config in
                recorder.recordConfig(config)
                return [config]
            }
            $0.onboardingProgressRepository.setCompletedOnboarding = { @Sendable value in
                recorder.recordOnboarding(value)
            }
            $0.uuidGenerator.generate = { fixedID }
            $0.dateProvider.now = { fixedDate }
        }

        let expectedConfig = state.serverConfig.form.makeServerConfig(
            id: fixedID,
            createdAt: fixedDate
        )

        await store.send(ServerFormReducer.Action.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(ServerFormReducer.Action.saveResponse(.success(expectedConfig))) {
            $0.isSaving = false
        }

        await store.receive(ServerFormReducer.Action.delegate(.didCreate(expectedConfig)))

        #expect(recorder.savedConfig == expectedConfig)
        #expect(recorder.savedCredentials?.password == "secret")
        #expect(recorder.onboardingCompleted == true)
    }

    @Test("Ошибка сохранения показывает alert")
    func testSaveFailureShowsAlert() async {
        // Проверяем, что при ошибке сохранения показывается alert с сообщением.
        let error = TestError(message: "Ошибка сохранения")

        var state = ServerFormReducer.State(mode: .add)
        state.serverConfig.form.host = "nas.local"
        state.serverConfig.form.port = "9091"

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.serverConfigRepository.upsert = { @Sendable _ in
                throw error
            }
        }

        await store.send(ServerFormReducer.Action.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(
            ServerFormReducer.Action.saveResponse(.failure(.init(message: error.message)))
        ) {
            $0.isSaving = false
            $0.alert = AlertFactory.simpleAlert(
                title: L10n.tr("onboarding.alert.saveFailed.title"),
                message: error.message,
                action: .dismiss
            )
        }
    }

    @Test("Сохранение в режиме edit не завершает онбординг")
    func testEditDoesNotCompleteOnboarding() async {
        // Проверяем, что при редактировании не выставляется completedOnboarding.
        let recorder = SaveRecorder()
        let server = ServerConfig.previewLocalHTTP

        var state = ServerFormReducer.State(mode: .edit(server))
        state.serverConfig.form.password = "secret"

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.credentialsRepository.save = { @Sendable credentials in
                recorder.recordCredentials(credentials)
            }
            $0.serverConfigRepository.upsert = { @Sendable config in
                recorder.recordConfig(config)
                return [config]
            }
            $0.onboardingProgressRepository.setCompletedOnboarding = { @Sendable value in
                recorder.recordOnboarding(value)
            }
        }

        let expectedConfig = state.serverConfig.form.makeServerConfig(
            id: server.id,
            createdAt: server.createdAt
        )

        await store.send(ServerFormReducer.Action.saveButtonTapped) {
            $0.isSaving = true
        }

        await store.receive(ServerFormReducer.Action.saveResponse(.success(expectedConfig))) {
            $0.isSaving = false
        }

        await store.receive(ServerFormReducer.Action.delegate(.didUpdate(expectedConfig)))

        #expect(recorder.onboardingCompleted == nil)
    }
}

private final class SaveRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var savedCredentials: TransmissionServerCredentials?
    private(set) var savedConfig: ServerConfig?
    private(set) var onboardingCompleted: Bool?

    func recordCredentials(_ credentials: TransmissionServerCredentials) {
        lock.lock()
        savedCredentials = credentials
        lock.unlock()
    }

    func recordConfig(_ config: ServerConfig) {
        lock.lock()
        savedConfig = config
        lock.unlock()
    }

    func recordOnboarding(_ value: Bool) {
        lock.lock()
        onboardingCompleted = value
        lock.unlock()
    }
}

private struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
