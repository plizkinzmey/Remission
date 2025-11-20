import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AddTorrentFeatureTests {
    @Test
    func submitMagnetAddsTorrentWithParameters() async {
        let captured = LockedValue<(String?, Data?, String?, Bool?, [String]?)?>(nil)

        var client = TransmissionClientDependency.placeholder
        client.torrentAdd = { filename, metainfo, downloadDir, paused, labels in
            captured.withValue { $0 = (filename, metainfo, downloadDir, paused, labels) }
            return TransmissionResponse(result: "success")
        }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            transmissionClient: client
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: environment,
                destinationPath: "/downloads",
                startPaused: true,
                tags: ["linux"]
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(.submitResponse(.success(.init()))) {
            $0.isSubmitting = false
        }
        await store.receive(.delegate(.closeRequested))
        #expect(captured.value?.0 == "magnet:?xt=urn:btih:demo")
        #expect(captured.value?.1 == nil)
        #expect(captured.value?.2 == "/downloads")
        #expect(captured.value?.3 == true)
        #expect(captured.value?.4 == ["linux"])
    }

    @Test
    func emptyDestinationShowsAlert() async {
        let environment = ServerConnectionEnvironment.preview(server: .previewLocalHTTP)
        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Magnet"
                ),
                connectionEnvironment: environment,
                destinationPath: "   "
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        await store.send(.submitButtonTapped) {
            $0.alert = AlertState {
                TextState("Укажите каталог загрузки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Поле каталога загрузки не может быть пустым.")
            }
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func withValue(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&_value)
        lock.unlock()
    }
}
