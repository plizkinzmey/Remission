import Foundation

extension TransmissionDomainMapper {
    func mapServerConfig(
        record: StoredServerConfigRecord,
        credentials: TransmissionServerCredentials?
    ) throws -> ServerConfig {
        guard record.name.isEmpty == false else {
            throw DomainMappingError.missingField(
                field: "name",
                context: "server-config"
            )
        }

        guard record.host.isEmpty == false else {
            throw DomainMappingError.missingField(
                field: "host",
                context: "server-config"
            )
        }

        guard record.port > 0 else {
            throw DomainMappingError.invalidValue(
                field: "port",
                description: "значение должно быть > 0",
                context: "server-config"
            )
        }

        let connection: ServerConfig.Connection = .init(
            host: record.host,
            port: record.port,
            path: record.path ?? "/transmission/rpc"
        )

        let security: ServerConfig.Security =
            record.isSecure
            ? .https(allowUntrustedCertificates: record.allowUntrustedCertificates)
            : .http

        let authentication: ServerConfig.Authentication? = try makeAuthentication(
            for: record,
            credentials: credentials
        )

        return ServerConfig(
            id: record.id,
            name: record.name,
            connection: connection,
            security: security,
            authentication: authentication,
            createdAt: record.createdAt ?? Date()
        )
    }

    func makeAuthentication(
        for record: StoredServerConfigRecord,
        credentials: TransmissionServerCredentials?
    ) throws -> ServerConfig.Authentication? {
        guard let username = record.username else {
            return nil
        }

        let expectedKey: TransmissionServerCredentialsKey = TransmissionServerCredentialsKey(
            host: record.host,
            port: record.port,
            isSecure: record.isSecure,
            username: username
        )

        if let credentialsKey = credentials?.key, credentialsKey != expectedKey {
            throw DomainMappingError.invalidValue(
                field: "credentials",
                description: "ключ не соответствует сохранённым настройкам сервера",
                context: "server-config"
            )
        }

        return ServerConfig.Authentication(
            username: username,
            credentialKey: expectedKey
        )
    }
}
