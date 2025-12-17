import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

// MARK: - Parser Dependency

#if canImport(ComposableArchitecture)
    @DependencyClient
    struct TorrentDetailParserDependency: Sendable {
        var parse: @Sendable (TransmissionResponse) throws -> Torrent
    }

    extension TorrentDetailParserDependency {
        fileprivate static let placeholder: Self = Self(
            parse: { _ in throw TorrentDetailParserDependencyError.notConfigured("parse") }
        )
    }

    enum TorrentDetailParserDependencyError: Error, LocalizedError, Sendable {
        case notConfigured(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let name):
                return
                    "TorrentDetailParserDependency.\(name) is not configured for this environment."
            }
        }
    }

    extension TorrentDetailParserDependency: DependencyKey {
        static let liveValue: Self = Self { response in
            try TorrentDetailParser().parse(response)
        }

        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        @preconcurrency var torrentDetailParser: TorrentDetailParserDependency {
            get { self[TorrentDetailParserDependency.self] }
            set { self[TorrentDetailParserDependency.self] = newValue }
        }
    }
#endif

enum TorrentDetailParserError: Error, LocalizedError, Equatable {
    case missingTorrentData
    case mappingFailed(DomainMappingError)

    var errorDescription: String? {
        switch self {
        case .missingTorrentData:
            return "Ошибка парсирования ответа сервера"
        case .mappingFailed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Parser Implementation

struct TorrentDetailParser: Sendable {
    private let mapper: TransmissionDomainMapper

    init(mapper: TransmissionDomainMapper = TransmissionDomainMapper()) {
        self.mapper = mapper
    }

    func parse(_ response: TransmissionResponse) throws -> Torrent {
        do {
            return try mapper.mapTorrentDetails(from: response)
        } catch let error as DomainMappingError {
            if case .emptyCollection = error {
                throw TorrentDetailParserError.missingTorrentData
            } else {
                throw TorrentDetailParserError.mappingFailed(error)
            }
        }
    }
}
