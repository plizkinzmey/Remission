import Dependencies
import DependenciesMacros
import Foundation
@preconcurrency import UserNotifications

@DependencyClient
public struct NotificationClient: Sendable {
    public enum AuthorizationStatus: Sendable {
        case notDetermined
        case denied
        case authorized
        case provisional
        case ephemeral
    }

    public var requestAuthorization: @Sendable (UNAuthorizationOptions) async throws -> Bool
    public var authorizationStatus: @Sendable () async -> AuthorizationStatus = { .notDetermined }
    public var sendNotification:
        @Sendable (_ title: String, _ body: String, _ identifier: String?) async throws -> Void
}

extension NotificationClient: DependencyKey {
    /// Настраивает обработку уведомлений. Должен быть вызван при старте приложения.
    public static func configure() {
        UNUserNotificationCenter.current().delegate = ForegroundNotificationDelegate.shared
    }

    public static var liveValue: NotificationClient {
        return NotificationClient(
            requestAuthorization: { options in
                try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            },
            authorizationStatus: {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                switch settings.authorizationStatus {
                case .notDetermined: return .notDetermined
                case .denied: return .denied
                case .authorized: return .authorized
                case .provisional: return .provisional
                case .ephemeral: return .ephemeral
                @unknown default: return .notDetermined
                }
            },
            sendNotification: { title, body, identifier in
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: identifier ?? UUID().uuidString,
                    content: content,
                    trigger: nil  // Deliver immediately
                )
                try await UNUserNotificationCenter.current().add(request)
            }
        )
    }

    public static var testValue: NotificationClient {
        NotificationClient()
    }

    public static var previewValue: NotificationClient {
        NotificationClient(
            requestAuthorization: { _ in true },
            authorizationStatus: { .authorized },
            sendNotification: { _, _, _ in }
        )
    }
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

/// Делегат для управления отображением уведомлений, когда приложение находится на переднем плане.
private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate,
    Sendable
{
    static let shared = ForegroundNotificationDelegate()

    override private init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Не показываем баннер, если приложение активно, как и просил пользователь.
        completionHandler([])
    }
}
