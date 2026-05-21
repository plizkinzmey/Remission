import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

struct TransmissionTrustStoreClient: Sendable {
    var deleteFingerprint: @Sendable (TransmissionServerTrustIdentity) throws -> Void
}

#if canImport(ComposableArchitecture)
    extension TransmissionTrustStoreClient: DependencyKey {
        static var liveValue: TransmissionTrustStoreClient {
            .live(serviceIdentifier: AppStorageNamespace.live().trustKeychainServiceIdentifier)
        }
        static let previewValue: TransmissionTrustStoreClient = .placeholder
        static let testValue: TransmissionTrustStoreClient = .placeholder
    }

    extension DependencyValues {
        var transmissionTrustStoreClient: TransmissionTrustStoreClient {
            get { self[TransmissionTrustStoreClient.self] }
            set { self[TransmissionTrustStoreClient.self] = newValue }
        }
    }
#endif

extension TransmissionTrustStoreClient {
    static let placeholder: TransmissionTrustStoreClient = TransmissionTrustStoreClient { _ in }

    static func live(
        store: TransmissionTrustStore = TransmissionTrustStore()
    ) -> TransmissionTrustStoreClient {
        TransmissionTrustStoreClient { identity in
            try store.deleteFingerprint(for: identity)
        }
    }

    static func live(
        serviceIdentifier: String
    ) -> TransmissionTrustStoreClient {
        live(store: TransmissionTrustStore(serviceIdentifier: serviceIdentifier))
    }
}
