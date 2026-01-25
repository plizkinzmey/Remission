import ComposableArchitecture
import Foundation

@testable import Remission

extension ServerConnectionEnvironment {
    static var previewValue: ServerConnectionEnvironment {
        let server = ServerConfig(
            name: "Preview Server",
            connection: .init(host: "localhost", port: 9091),
            security: .http,
            authentication: .init(username: "admin")
        )
        return .preview(server: server)
    }
}
