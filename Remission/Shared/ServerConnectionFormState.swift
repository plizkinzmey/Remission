import ComposableArchitecture
import Foundation

@ObservableState
struct ServerConnectionFormState: Equatable, Sendable {
    enum Transport: String, CaseIterable, Hashable, Sendable {
        case https
        case http

        var title: String {
            switch self {
            case .https: return L10n.tr("serverForm.transport.https")
            case .http: return L10n.tr("serverForm.transport.http")
            }
        }
    }

    var name: String = ""
    var host: String = ""
    var port: String = "9091"
    var path: String = "/transmission/rpc"
    var transport: Transport = .http
    var username: String = ""
    var password: String = ""

    init() {}

    init(server: ServerConfig) {
        self.name = server.name
        self.host = server.connection.host
        self.port = "\(server.connection.port)"
        self.path = server.connection.path
        switch server.security {
        case .http:
            self.transport = .http
        case .https:
            self.transport = .https
        }
        self.username = server.authentication?.username ?? ""
    }

    var trimmedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedHost: String {
        let trimmed = trimmedHost
        return trimmed.isEmpty ? host : trimmed
    }

    var normalizedPath: String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "/transmission/rpc" }
        return trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
    }

    var portValue: Int? {
        guard let value = Int(port), (1...65535).contains(value) else { return nil }
        return value
    }

    var isFormValid: Bool {
        trimmedHost.isEmpty == false && portValue != nil
    }

    var normalizedName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? normalizedHost : trimmedName
    }

    var usesInsecureTransport: Bool {
        transport == .http
    }

    mutating func load(from server: ServerConfig, password: String?) {
        name = server.name
        host = server.connection.host
        port = "\(server.connection.port)"
        path = server.connection.path
        switch server.security {
        case .http:
            transport = .http
        case .https:
            transport = .https
        }
        username = server.authentication?.username ?? ""
        self.password = password ?? ""
    }

    func makeServerConfig(
        id: UUID,
        createdAt: Date
    ) -> ServerConfig {
        let connection = ServerConfig.Connection(
            host: normalizedHost,
            port: portValue ?? 9091,
            path: normalizedPath
        )
        let security: ServerConfig.Security =
            transport == .https
            ? .https
            : .http

        var authentication: ServerConfig.Authentication?
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            authentication = ServerConfig.Authentication(username: username)
        }

        return ServerConfig(
            id: id,
            name: normalizedName,
            connection: connection,
            security: security,
            authentication: authentication,
            createdAt: createdAt
        )
    }
}
