import ComposableArchitecture
import Foundation

@testable import Remission

extension ServerConnectionEnvironment {
    static let testServerID = UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF")!

    static var previewValue: ServerConnectionEnvironment {
        let server = ServerConfig(
            id: testServerID,
            name: "Preview Server",
            connection: .init(host: "localhost", port: 9091),
            security: .http,
            authentication: .init(username: "admin")
        )
        return .preview(server: server)
    }
}
