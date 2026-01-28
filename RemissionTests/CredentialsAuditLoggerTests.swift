import Foundation
import Testing

@testable import Remission

@Suite("Credentials Audit Logger Tests")
struct CredentialsAuditLoggerTests {
    // Проверяет вычисляемые свойства дескриптора сервера без утечки секретов.
    @Test
    func serverDescriptorBuildsSchemeEndpointAndMaskedUsername() {
        let key = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "admin"
        )
        let descriptor = CredentialsServerDescriptor(key: key)

        #expect(descriptor.scheme == "http")
        #expect(descriptor.endpointDescription == "http://nas.local:9091")
        #expect(descriptor.maskedUsername.contains("••••"))
        #expect(descriptor.maskedUsername != "admin")
    }

    // Проверяет формат сообщения для ошибок, чтобы в логах был reason.
    @Test
    func eventMessageIncludesReasonForFailures() {
        let descriptor = CredentialsServerDescriptor(
            key: .init(host: "seedbox.io", port: 443, isSecure: true, username: "user")
        )
        let event = CredentialsAuditEvent.saveFailed(descriptor, "network")
        let message = event.message()

        #expect(message.contains("save failed"))
        #expect(message.contains("network"))
        #expect(message.contains(descriptor.endpointDescription))
    }

    // Проверяет, что eventSink вызывается с тем же событием.
    @Test
    func loggerForwardsEventToSink() {
        final class Box: @unchecked Sendable {
            var event: CredentialsAuditEvent?
        }

        let box = Box()
        let logger = CredentialsAuditLogger(
            appLogger: .noop,
            eventSink: { event in box.event = event }
        )

        let descriptor = CredentialsServerDescriptor(
            key: .init(host: "host", port: 1, isSecure: false, username: "u")
        )
        let event = CredentialsAuditEvent.loadMissing(descriptor)
        logger(event)

        #expect(box.event == event)
    }
}
