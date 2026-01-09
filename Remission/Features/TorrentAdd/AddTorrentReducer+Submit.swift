import ComposableArchitecture
import Foundation

extension AddTorrentReducer {
    // swiftlint:disable function_body_length
    func handleSubmit(state: inout State) -> Effect<Action> {
        guard let input = state.pendingInput else { return .none }
        let destinationRaw = state.destinationPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard destinationRaw.isEmpty == false else {
            state.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.destinationRequired.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("torrentAdd.alert.destinationRequired.message"))
            }
            state.closeOnAlertDismiss = false
            return .none
        }

        let destination = normalizeDestination(
            destinationRaw,
            defaultDownloadDirectory: state.serverDownloadDirectory
        )
        if destination != destinationRaw {
            state.destinationPath = destination
        }

        guard let environment = state.connectionEnvironment else {
            state.alert = AlertState {
                TextState(L10n.tr("torrentAdd.alert.noConnection.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("common.ok"))
                }
            } message: {
                TextState(L10n.tr("torrentAdd.alert.noConnection.message"))
            }
            state.closeOnAlertDismiss = false
            return .none
        }

        let tags = state.tags.isEmpty ? nil : state.tags
        let startPaused = state.startPaused
        state.isSubmitting = true
        state.closeOnAlertDismiss = false

        return .run { send in
            let result = await Result {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    try await torrentRepository.add(
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

    func successAlert(
        for result: TorrentRepository.AddResult
    ) -> AlertState<AlertAction> {
        let isDuplicate: Bool = result.status == .duplicate
        let title: TextState =
            isDuplicate
            ? TextState(L10n.tr("torrentAdd.alert.duplicate.title"))
            : TextState(L10n.tr("torrentAdd.alert.added.title"))
        let message: TextState =
            isDuplicate
            ? TextState(
                String(
                    format: L10n.tr("torrentAdd.alert.duplicate.message"),
                    result.name
                )
            )
            : TextState(
                String(
                    format: L10n.tr("torrentAdd.alert.added.message"),
                    result.name
                )
            )

        return AlertState {
            title
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            message
        }
    }

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

    func normalizeDestination(
        _ destination: String,
        defaultDownloadDirectory: String
    ) -> String {
        let base = defaultDownloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard base.isEmpty == false else { return destination }

        let hasNestedPath = destination.hasPrefix("/") && destination.dropFirst().contains("/")
        if hasNestedPath {
            return destination
        }

        let trimmedComponent = destination.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard trimmedComponent.isEmpty == false else { return destination }

        let normalizedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        return normalizedBase + "/" + trimmedComponent
    }
}
