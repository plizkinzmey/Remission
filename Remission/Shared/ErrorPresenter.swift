import ComposableArchitecture
import Foundation

/// Общий presenter для отображения ошибок через инлайновый баннер и TCA-managed alert.
/// Держит опциональный retry, чтобы родительский reducer мог детерминированно повторить исходное действие.
@Reducer
struct ErrorPresenter<Retry: Equatable & Sendable>: Sendable {
    @ObservableState
    struct State: Equatable, Sendable {
        /// Текущий баннер, если показан.
        var banner: Banner?
        /// AlertState с кнопками retry/cancel.
        @Presents var alert: AlertState<AlertAction>?
        /// Запоминает retry для алерта, чтобы пробросить его наружу после действия пользователя.
        var pendingRetry: Retry?
    }

    enum Action: Equatable, Sendable {
        case showBanner(message: String, retry: Retry?)
        case showAlert(title: String, message: String, retry: Retry?)
        case bannerDismissed
        case bannerRetryTapped
        case alert(PresentationAction<AlertAction>)
        case retryRequested(Retry)
    }

    enum AlertAction: Equatable, Sendable {
        case retry
        case dismiss
    }

    struct Banner: Identifiable, Sendable, Equatable {
        var id: UUID = UUID()
        var message: String
        var retry: Retry?

        static func == (lhs: Banner, rhs: Banner) -> Bool {
            lhs.message == rhs.message && lhs.retry == rhs.retry
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showBanner(let message, let retry):
                state.banner = Banner(message: message, retry: retry)
                return .none

            case .showAlert(let title, let message, let retry):
                state.pendingRetry = retry
                state.alert = makeAlert(
                    title: title,
                    message: message,
                    hasRetry: retry != nil
                )
                return .none

            case .bannerDismissed:
                state.banner = nil
                return .none

            case .bannerRetryTapped:
                guard let retry = state.banner?.retry else {
                    state.banner = nil
                    return .none
                }
                state.banner = nil
                return .send(.retryRequested(retry))

            case .alert(.presented(.retry)):
                guard let retry = state.pendingRetry else {
                    state.alert = nil
                    return .none
                }
                state.pendingRetry = nil
                state.alert = nil
                return .send(.retryRequested(retry))

            case .alert(.presented(.dismiss)):
                state.pendingRetry = nil
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .retryRequested:
                return .none
            }
        }
    }

    private func makeAlert(
        title: String,
        message: String,
        hasRetry: Bool
    ) -> AlertState<AlertAction> {
        AlertState {
            TextState(title)
        } actions: {
            if hasRetry {
                ButtonState(action: .retry) {
                    TextState(L10n.tr("common.retry"))
                }
            }
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }
}

extension Error {
    /// Возвращает понятное пользователю описание ошибки.
    var userFacingMessage: String {
        if let localized = self as? LocalizedError,
            let description = localized.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let nsError = self as NSError
        return nsError.localizedDescription.isEmpty
            ? String(describing: self)
            : nsError.localizedDescription
    }
}
