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
                TextState(
                    String(
                        format: L10n.tr("serverList.alert.delete.title"),
                        server.name
                    )
                )
            } actions: {
                ButtonState(role: .destructive, action: .confirm) {
                    TextState(L10n.tr("serverList.alert.delete.confirm"))
                }
                ButtonState(role: .cancel, action: .cancel) {
                    TextState(L10n.tr("serverList.alert.delete.cancel"))
                }
            } message: {
                TextState(L10n.tr("serverList.alert.delete.message"))
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

    @Test
    func connectionProbeSuccessUpdatesStatus() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.6",
            isCompatible: true
        )
        let probeCalls = LockedValue<[UUID]>([])

        let store = TestStoreFactory.makeServerListTestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.serverConfigRepository = .inMemory(initial: [server])
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in }
                )
                dependencies.serverConnectionProbe = ServerConnectionProbe { request, _ in
                    probeCalls.withValue { $0.append(request.server.id) }
                    return .init(handshake: handshake)
                }
            })

        await store.send(.serverRepositoryResponse(.success([server]))) {
            $0.servers = [server]
            $0.connectionStatuses = [:]
        }

        await store.receive(.connectionProbeRequested(server.id)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await store.receive(
            .connectionProbeResponse(server.id, .success(.init(handshake: handshake)))
        ) {
            $0.connectionStatuses[server.id] = .init(phase: .connected(handshake))
        }

        #expect(probeCalls.value == [server.id])
    }

    @Test
    func connectionProbeMissingCredentialsFails() async {
        let server: ServerConfig = {
            var value = ServerConfig.previewSecureSeedbox
            value.id = UUID()
            return value
        }()

        let store = TestStoreFactory.makeServerListTestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.serverConfigRepository = .inMemory(initial: [server])
                dependencies.credentialsRepository = .previewMock(load: { _ in nil })
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in }
                )
                dependencies.serverConnectionProbe = .placeholder
            })

        await store.send(.connectionProbeRequested(server.id)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await store.receive(
            .connectionProbeResponse(
                server.id,
                .failure(ServerConnectionEnvironmentFactoryError.missingCredentials)
            )
        ) {
            $0.connectionStatuses[server.id] = .init(
                phase: .failed("Не удалось найти пароль для выбранного сервера.")
            )
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

// swiftlint:enable function_body_length
