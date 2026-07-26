import SwiftUI
import Testing

@testable import Remission

@Suite("Sanitized Text Field Tests")
@MainActor
struct SanitizedTextFieldTests {
    @Test
    func sanitizationCleansCyrillicPassword() async {
        var state = ServerConnectionFormState()
        let binding = Binding<String>(
            get: { state.password },
            set: { state.password = $0 }
        )

        _ = SanitizedTextField("Password", text: binding, isSecure: true)

        // Emulate entering valid password
        state.password = "P@$$w0rd"
        #expect(state.password == "P@$$w0rd")

        // Emulate entering password with Cyrillic (which is filtered out)
        state.password = "пароль P@$$w0rd"
        #expect(state.password == " P@$$w0rd")
    }

    @Test
    func hostFieldRejectsCyrillicAndSpaces() async {
        var state = ServerConnectionFormState()

        state.host = "хост.local"
        #expect(state.host == ".local")

        state.host = "my host.com"
        #expect(state.host == "myhost.com")
    }

    @Test
    func portFieldRestrictsToDigitsAndLength() async {
        var state = ServerConnectionFormState()

        state.port = "90a912"
        #expect(state.port == "90912")

        state.port = "123456"
        #expect(state.port == "12345")
    }

    @Test
    func pathFieldRejectsCyrillicAndSpaces() async {
        var state = ServerConnectionFormState()

        state.path = "/путь/rpc"
        #expect(state.path == "//rpc")

        state.path = "/transmission /rpc"
        #expect(state.path == "/transmission/rpc")
    }
}
