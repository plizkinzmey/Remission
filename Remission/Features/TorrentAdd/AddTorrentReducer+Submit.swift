import ComposableArchitecture
import Foundation

extension AddTorrentReducer {
    func loadDefaultDownloadDirectory(
        environment: ServerConnectionEnvironment
    ) -> Effect<Action> {
        .run { send in
            await send(
                .defaultDownloadDirectoryResponse(
                    TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            let state = try await sessionRepository.fetchState()
                            return state.downloadDirectory
                        }
                    }
                )
            )
        }
        .cancellable(id: AddTorrentCancelID.loadDefaults, cancelInFlight: true)
    }

    func loadPreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
    }

    func persistRecentDownloadDirectories(state: inout State) -> Effect<Action> {
        guard let serverID = state.serverID else { return .none }
        let updated = updatedRecentDirectories(
            current: state.recentDownloadDirectories,
            newValue: state.destinationPath,
            defaultDirectory: state.serverDownloadDirectory
        )
        state.recentDownloadDirectories = updated
        return .run { send in
            await send(
                .preferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.updateRecentDownloadDirectories(
                            serverID: serverID,
                            updated
                        )
                    }
                )
            )
        }
    }

    // swiftlint:disable function_body_length
    func handleSubmit(state: inout State) -> Effect<Action> {
        guard let input = state.pendingInput else { return .none }
        let destinationRaw = state.destinationPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard destinationRaw.isEmpty == false else {
            state.alert = AlertFactory.destinationRequired(action: .dismiss)
            state.closeOnAlertDismiss = false
            return .none
        }

        let destination = TransmissionPathNormalization.normalize(
            destinationRaw,
            defaultDownloadDirectory: state.serverDownloadDirectory
        )
        if destination != destinationRaw {
            state.destinationPath = destination
        }

        guard let environment = state.connectionEnvironment else {
            state.alert = AlertFactory.noConnection(action: .dismiss)
            state.closeOnAlertDismiss = false
            return .none
        }

        let tags = TorrentCategory.tags(for: state.category)
        let startPaused = state.startPaused
        state.isSubmitting = true
        state.closeOnAlertDismiss = false

        return .run { send in
            let result = await Result {
                try await environment.withDependencies {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    return try await repository.add(
                        input,
                        destinationPath: destination,
                        startPaused: startPaused,
                        tags: tags
                    )
                }
            }

            switch result {
            case .success(let response):
                await send(.submitResponse(.success(.init(addResult: response))))
            case .failure(let error):
                await send(.submitResponse(.failure(mapSubmitError(error))))
            }
        }
        .cancellable(id: AddTorrentCancelID.submit, cancelInFlight: true)
    }
    // swiftlint:enable function_body_length

    func mapSubmitError(_ error: Error) -> SubmitError {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return .unauthorized
            case .sessionConflict:
                return .sessionConflict
            case .unknown(let details):
                return .failed(details)
            default:
                return .failed(apiError.localizedDescription)
            }
        }

        if let mappingError = error as? DomainMappingError {
            return .mapping(mappingError.localizedDescription)
        }

        return .failed(error.localizedDescription)
    }

    func normalizedRecentDirectories(
        _ directories: [String],
        defaultDirectory: String
    ) -> [String] {
        let sanitized =
            directories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        var unique: [String] = []
        for value in sanitized where unique.contains(value) == false {
            unique.append(value)
        }
        let normalizedDefault = defaultDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return unique.filter { $0 != normalizedDefault }
    }

    func updatedRecentDirectories(
        current: [String],
        newValue: String,
        defaultDirectory: String
    ) -> [String] {
        let normalizedDefault = defaultDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var base = normalizedRecentDirectories(current, defaultDirectory: defaultDirectory)
        guard trimmed.isEmpty == false else { return base }
        guard trimmed != normalizedDefault else { return base }
        base.removeAll { $0 == trimmed }
        base.insert(trimmed, at: 0)
        if base.count > maxRecentDirectories {
            base = Array(base.prefix(maxRecentDirectories))
        }
        return base
    }

    var maxRecentDirectories: Int { 8 }
}