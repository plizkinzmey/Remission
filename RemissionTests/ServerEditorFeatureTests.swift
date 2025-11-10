import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerEditorFeatureTests {
    @Test("task loads password from Keychain once")
    func loadPasswordOnTask() async {
        let server = ServerConfig.previewSecureSeedbox
        let loadedKeys = LockedValue<[TransmissionServerCredentialsKey]>([])

        let store = TestStore(
            initialState: ServerEditorReducer.State(server: server)
        ) {
            ServerEditorReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.credentialsRepository = CredentialsRepository(
                save: { _ in },
                load: { key in
                    loadedKeys.withValue { $0.append(key) }
                    return TransmissionServerCredentials(key: key, password: "stored-secret")
                },
                delete: { _ in }
            )
        }

        await store.send(.task) {
            $0.hasLoadedCredentials = true
        }

        await store.receive(.credentialsLoaded("stored-secret")) {
            $0.form.password = "stored-secret"
        }

        await store.send(.task)
        #expect(loadedKeys.value.count == 1)
    }

    @Test("saveButtonTapped persists server and credentials")
    func saveUpdatesServerAndCredentials() async {
        let server = ServerConfig.previewLocalHTTP
        var initialState = ServerEditorReducer.State(server: server)
        initialState.form.name = "Updated NAS"
        initialState.form.host = "nas.example.com"
        initialState.form.port = "9092"
        initialState.form.path = "/new-rpc"
        initialState.form.password = "updated-secret"
        initialState.form.transport = .https

        let savedServer = LockedValue<ServerConfig?>(nil)
        let savedCredentials = LockedValue<TransmissionServerCredentials?>(nil)
        let deletedKeys = LockedValue<[TransmissionServerCredentialsKey]>([])

        let store = TestStore(initialState: initialState) {
            ServerEditorReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConfigRepository = ServerConfigRepository(
                load: { [] },
                upsert: { value in
                    savedServer.set(value)
                    return [value]
                },
                delete: { _ in [] }
            )
            dependencies.credentialsRepository = CredentialsRepository(
                save: { credentials in savedCredentials.set(credentials) },
                load: { _ in nil },
                delete: { key in deletedKeys.withValue { $0.append(key) } }
            )
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore.inMemory()
        }

        let expectedServer = initialState.form.makeServerConfig(
            id: server.id,
            createdAt: server.createdAt
        )

        await store.send(.saveButtonTapped) {
            $0.validationError = nil
            $0.pendingWarningFingerprint = nil
            $0.isSaving = true
        }

        await store.receive(.saveCompleted(.success(expectedServer))) {
            $0.isSaving = false
            $0.server = expectedServer
        }

        await store.receive(.delegate(.didUpdate(expectedServer)))

        #expect(savedServer.value == expectedServer)
        #expect(savedCredentials.value?.password == "updated-secret")
        #expect(
            deletedKeys.value
                == [server.credentialsKey].compactMap { $0 }
        )
    }

    @Test("save failure surfaces alert and keeps editor open")
    func saveFailureShowsAlert() async {
        let server = ServerConfig.previewSecureSeedbox
        var initialState = ServerEditorReducer.State(server: server)
        initialState.form.name = "Seedbox"
        initialState.form.transport = .https

        enum StubError: LocalizedError {
            case failure
            var errorDescription: String? { "Stub failure" }
        }

        let store = TestStore(initialState: initialState) {
            ServerEditorReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConfigRepository = ServerConfigRepository(
                load: { [] },
                upsert: { _ in throw StubError.failure },
                delete: { _ in [] }
            )
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore.inMemory()
        }

        await store.send(.saveButtonTapped) {
            $0.validationError = nil
            $0.pendingWarningFingerprint = nil
            $0.isSaving = true
        }

        await store.receive(
            .saveCompleted(.failure(ServerEditorReducer.EditorError(message: "Stub failure")))
        ) {
            $0.isSaving = false
            $0.alert = AlertState {
                TextState("Не удалось сохранить сервер")
            } actions: {
                ButtonState(role: .cancel, action: .errorDismissed) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Stub failure")
            }
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ newValue: Value) {
        lock.lock()
        storage = newValue
        lock.unlock()
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&storage)
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
