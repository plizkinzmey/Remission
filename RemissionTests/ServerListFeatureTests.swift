import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerListFeatureTests {
    @Test
    func addButtonOpensOnboarding() async {
        let store = TestStoreFactory.makeServerListTestStore(configure: { dependencies in
            dependencies.transmissionClient = .testValue
            dependencies.serverConfigRepository = .inMemory(initial: [])
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in },
                isInsecureWarningAcknowledged: { _ in true },
                acknowledgeInsecureWarning: { _ in }
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
                    setCompletedOnboarding: { _ in },
                    isInsecureWarningAcknowledged: { _ in true },
                    acknowledgeInsecureWarning: { _ in }
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
                setCompletedOnboarding: { _ in },
                isInsecureWarningAcknowledged: { _ in true },
                acknowledgeInsecureWarning: { _ in }
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
    func removeDeletesServerViaRepository() async {
        let server: ServerConfig = {
            var value = ServerConfig.previewLocalHTTP
            value.id = UUID()
            return value
        }()
        let removedIDs = LockedValue<[UUID]>([])

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
                dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                    hasCompletedOnboarding: { true },
                    setCompletedOnboarding: { _ in },
                    isInsecureWarningAcknowledged: { _ in true },
                    acknowledgeInsecureWarning: { _ in }
                )
            })

        await store.send(.remove(IndexSet(integer: 0))) {
            $0.servers = []
        }
        await store.receive(.serverRepositoryResponse(.success([]))) {
            $0.isLoading = false
        }
        #expect(removedIDs.value == [server.id])
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

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
