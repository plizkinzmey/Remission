import ComposableArchitecture
import Foundation

// swiftlint:disable nesting

// MARK: - Error Types

extension ServerDetailReducer {
    enum FileImportResult: Equatable {
        case success(URL)
        case failure(String)
    }

    enum FileImportError: Equatable, Error {
        case failed(String)

        var message: String {
            switch self {
            case .failed(let message):
                return message
            }
        }
    }

    struct DeletionError: Equatable, Error {
        var message: String
    }

    enum DeletionResult: Equatable {
        case success
        case failure(DeletionError)
    }
}

// MARK: - Connection State

extension ServerDetailReducer {
    struct ConnectionState: Equatable {
        struct Ready: Equatable {
            var fingerprint: String
            var handshake: TransmissionHandshakeResult
        }

        struct Failure: Equatable {
            var message: String
        }

        struct Offline: Equatable {
            var message: String
            var attempt: Int
        }

        enum Phase: Equatable {
            case idle
            case connecting
            case ready(Ready)
            case offline(Offline)
            case failed(Failure)
        }

        var phase: Phase = .idle

        var failureMessage: String? {
            switch phase {
            case .failed(let failure):
                return failure.message
            case .offline(let offline):
                return offline.message
            default:
                return nil
            }
        }
    }

    struct ConnectionResponse: Equatable {
        var environment: ServerConnectionEnvironment
        var handshake: TransmissionHandshakeResult
    }
}

// swiftlint:enable nesting
