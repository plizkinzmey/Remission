#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies

    extension TransmissionClientDependency: DependencyKey {
        /// Возвращает рабочую live-реализацию, собранную через TransmissionClientBootstrap.
        /// При недоступной конфигурации откатывается к безопасному placeholder.
        static var liveValue: Self {
            TransmissionClientBootstrap.makeLiveDependency(
                dependencies: DependencyValues.appDefault()
            )
        }
    }

    extension TransmissionClientDependency {
        static func live(client: TransmissionClientProtocol) -> Self {
            Self(
                sessionGet: {
                    try await client.sessionGet()
                },
                sessionSet: { arguments in
                    try await client.sessionSet(arguments: arguments)
                },
                sessionStats: {
                    try await client.sessionStats()
                },
                freeSpace: { path in
                    try await client.freeSpace(path: path)
                },
                torrentGet: { ids, fields in
                    try await client.torrentGet(ids: ids, fields: fields)
                },
                torrentAdd: { filename, metainfo, downloadDir, paused, labels in
                    try await client.torrentAdd(
                        filename: filename,
                        metainfo: metainfo,
                        downloadDir: downloadDir,
                        paused: paused,
                        labels: labels
                    )
                },
                torrentStart: { ids in try await client.torrentStart(ids: ids) },
                torrentStop: { ids in
                    try await client.torrentStop(ids: ids)
                },
                torrentRemove: { ids, deleteLocalData in
                    try await client.torrentRemove(
                        ids: ids,
                        deleteLocalData: deleteLocalData
                    )
                },
                torrentSet: { ids, arguments in
                    try await client.torrentSet(ids: ids, arguments: arguments)
                },
                torrentVerify: { ids in
                    try await client.torrentVerify(ids: ids)
                },
                checkServerVersion: {
                    try await client.checkServerVersion()
                },
                performHandshake: {
                    try await client.performHandshake()
                },
                setTrustDecisionHandler: { handler in
                    client.setTrustDecisionHandler(handler)
                }
            )
        }
    }
#endif
