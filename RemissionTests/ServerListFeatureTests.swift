import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length

@MainActor
struct ServerListFeatureTests {
    @Test
    func addButtonOpensOnboarding() async {
        let store = TestStoreFactory.makeServerListTestStore(configure: { dependencies in
            dependencies.transmissionClient = .testValue
            dependencies.serverConfigRepository = .inMemory(initial: [])
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in }
            )
        })

        await store.send(.addButtonTapped) {
            $0.hasPresentedInitialOnboarding = true
            $0.onboarding = OnboardingReducer.State()
        }
    }

    @Test
    func selectingServerTriggersDelegate() async {
        let identifier = UUID()
        let server: ServerConfig = {
            var value = ServerConfig.previewSecureSeedbox
            value.id = identifier
            return value
        }()
        let store = TestStoreFactory.makeServerListTestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.transmissionClient = .testValue
                dependencies.serverConfigRepository = .inMemory(initial: [server])
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in }
                )
            })

        await store.send(.serverTapped(identifier))
        await store.receive(.delegate(.serverSelected(server)))
    }

    @Test
    func taskLoadsServersFromRepository() async {
        let storedServers = [
            ServerConfig.previewLocalHTTP,
            ServerConfig.previewSecureSeedbox
        ]
        let store = TestStoreFactory.makeServerListTestStore(configure: { dependencies in
            dependencies.transmissionClient = .testValue
            dependencies.serverConfigRepository = ServerConfigRepository(
                load: { storedServers },
                upsert: { _ in storedServers },
                delete: { _ in storedServers }
            )
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in }
            )
        })

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.serverRepositoryResponse(.success(storedServers))) {
            $0.isLoading = false
            $0.servers = IdentifiedArrayOf(uniqueElements: storedServers)
        }
    }

    @Test
    func deleteRequiresConfirmationBeforeRemoving() async {
        let server: ServerConfig = {
            var value = ServerConfig.previewLocalHTTP
            value.id = UUID()
            return value
        }()
        let removedIDs = LockedValue<[UUID]>([])
        let deletedCredentialKeys = LockedValue<[TransmissionServerCredentialsKey]>([])

        let store = TestStoreFactory.makeServerListTestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.transmissionClient = .testValue
                dependencies.serverConfigRepository = ServerConfigRepository(
                    load: { [server] },
                    upsert: { _ in [server] },
                    delete: { ids in
                        removedIDs.set(ids)
                        return []
                    }
                )
                dependencies.credentialsRepository = CredentialsRepository.previewMock(
                    delete: { key in
                        var collected = deletedCredentialKeys.value
                        collected.append(key)
                        deletedCredentialKeys.set(collected)
                    }
                )
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in }
                )
            })

        await store.send(.deleteButtonTapped(server.id)) {
            $0.pendingDeletion = server
            $0.deleteConfirmation = ConfirmationDialogState {
                TextState("Удалить «\(server.name)»?")
            } actions: {
                ButtonState(role: .destructive, action: .confirm) {
                    TextState("Удалить")
                }
                ButtonState(role: .cancel, action: .cancel) {
                    TextState("Отмена")
                }
            } message: {
                TextState(
                    "Сервер и сохранённые креды будут удалены без "
                        + "возможности восстановления."
                )
            }
        }

        await store.send(.deleteConfirmation(.presented(.confirm))) {
            $0.pendingDeletion = nil
            $0.deleteConfirmation = nil
        }

        await store.receive(.serverRepositoryResponse(.success([]))) {
            $0.isLoading = false
            $0.servers = []
        }
        #expect(removedIDs.value == [server.id])
        #expect(deletedCredentialKeys.value == [server.credentialsKey].compactMap { $0 })
    }

    @Test
    func editActionNotifiesDelegate() async {
        let server = ServerConfig.previewSecureSeedbox
        let store = TestStoreFactory.makeServerListTestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.transmissionClient = .testValue
                dependencies.serverConfigRepository = .inMemory(initial: [server])
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in }
                )
            })

        await store.send(.editButtonTapped(server.id))
        await store.receive(.delegate(.serverEditRequested(server)))
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

// swiftlint:enable function_body_length
