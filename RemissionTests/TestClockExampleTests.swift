import Clocks
import ComposableArchitecture
import Dependencies
import Foundation
import Testing

@testable import Remission

@MainActor
struct TestClockExampleTests {
    /// Демонстрация использования `TestClock`/`AsyncClock` в TCA-тесте, как подготовка к будущим polling-эффектам.
    @Test
    func pollingEffectUsesTestClock() async {
        let clock = TestClock()
        let store = TestStoreFactory.make(
            initialState: PollingTestReducer.State(),
            reducer: { PollingTestReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.transmissionClient = .testValue
            }
        )

        await store.send(.beginPolling)
        await clock.advance(by: .seconds(15))

        await store.receive(.pollingTick) {
            $0.ticks = 1
        }
    }
}

@Reducer
private struct PollingTestReducer {
    @ObservableState
    struct State: Equatable {
        var ticks: Int = 0
    }

    enum Action: Equatable {
        case beginPolling
        case pollingTick
    }

    enum CancelID: Hashable {
        case polling
    }

    @Dependency(\.appClock) private var appClock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .beginPolling:
                return .run { send in
                    let clock = appClock.clock()
                    do {
                        try await clock.sleep(for: .seconds(15))
                        await send(.pollingTick)
                    } catch is CancellationError {
                        return
                    } catch {
                        return
                    }
                }
                .cancellable(id: CancelID.polling, cancelInFlight: true)

            case .pollingTick:
                state.ticks += 1
                return .none
            }
        }
    }
}
