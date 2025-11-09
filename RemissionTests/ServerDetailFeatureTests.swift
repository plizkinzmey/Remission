import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerDetailFeatureTests {
    @Test
    func resetTrustClearsStores() async {
        let fingerprint = LockedValue<String?>(nil)
        let identityCapture = LockedValue<TransmissionServerTrustIdentity?>(nil)

        let server = ServerConfig.previewSecureSeedbox
        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.httpWarningPreferencesStore = HttpWarningPreferencesStore(
                isSuppressed: { _ in false },
                setSuppressed: { _, _ in },
                reset: { value in fingerprint.set(value) }
            )
            dependencies.transmissionTrustStoreClient = TransmissionTrustStoreClient { identity in
                identityCapture.set(identity)
            }
        }

        await store.send(.resetTrustButtonTapped) {
            $0.alert = AlertState {
                TextState("Сбросить доверие?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmReset) {
                    TextState("Сбросить")
                }
                ButtonState(role: .cancel, action: .cancelReset) {
                    TextState("Отмена")
                }
            } message: {
                TextState(
                    "Удалим сохранённые отпечатки сертификатов и решения \"Не предупреждать\"."
                )
            }
        }

        await store.send(.alert(.presented(.confirmReset))) {
            $0.alert = nil
        }

        await store.receive(.resetTrustSucceeded) {
            $0.alert = AlertState {
                TextState("Доверие сброшено")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Готово")
                }
            } message: {
                TextState("При следующем подключении мы снова спросим подтверждение.")
            }
        }

        #expect(fingerprint.value == server.httpWarningFingerprint)
        #expect(
            identityCapture.value
                == TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                ))
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    init(_ value: Value) {
        self.storage = value
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
