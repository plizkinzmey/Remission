import Foundation

/// Storage namespace for a concrete app runtime.
///
/// Release keeps the historical names so existing user data stays in place. Debug/dev runs use
/// separate filesystem, UserDefaults, and Keychain namespaces to avoid touching release data.
enum AppStorageNamespace: Equatable, Sendable {
    case release
    case development
    case unitTesting(id: UUID)
    case uiTesting(suiteName: String?)

    private enum Constants {
        static let overrideKey = "REMISSION_STORAGE_NAMESPACE"
        static let uiTestingPreferencesSuiteKey = "UI_TESTING_PREFERENCES_SUITE"
        static let releaseBundleID = "cryptolin.Remission"
        static let developmentBundleID = "cryptolin.Remission.dev"
    }

    private static let unitTestingID = UUID()

    static func live(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> Self {
        if let override = environment[Constants.overrideKey] {
            switch override.lowercased() {
            case "release", "production", "prod":
                return .release
            case "development", "debug", "dev":
                return .development
            case "ui-testing", "uitesting", "test":
                return .uiTesting(suiteName: environment[Constants.uiTestingPreferencesSuiteKey])
            default:
                break
            }
        }

        if environment["XCTestConfigurationFilePath"] != nil {
            return .unitTesting(id: unitTestingID)
        }

        if bundleIdentifier == Constants.developmentBundleID {
            return .development
        }

        #if DEBUG
            return .development
        #else
            if bundleIdentifier == Constants.releaseBundleID {
                return .release
            }
            return .release
        #endif
    }

    var applicationSupportDirectoryName: String {
        switch self {
        case .release:
            return "Remission"
        case .development:
            return "Remission-Dev"
        case .unitTesting(let id):
            return "Remission-Test-\(id.uuidString)"
        case .uiTesting:
            return "Remission-UITests"
        }
    }

    func applicationSupportDirectoryURL(fileManager: FileManager = .default) -> URL {
        let base: URL?
        switch self {
        case .release, .development, .uiTesting:
            base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        case .unitTesting:
            base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        }
        return (base ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))
            .appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
    }

    var userDefaultsSuiteName: String? {
        switch self {
        case .release:
            return nil
        case .development:
            return "com.remission.dev"
        case .unitTesting(let id):
            return "com.remission.test-\(id.uuidString)"
        case .uiTesting(let suiteName):
            return suiteName ?? "com.remission.ui-testing"
        }
    }

    var credentialsKeychainServiceIdentifier: String {
        switch self {
        case .release:
            return "com.remission.transmission"
        case .development:
            return "com.remission.transmission.dev"
        case .unitTesting(let id):
            return "com.remission.transmission.test-\(id.uuidString)"
        case .uiTesting:
            return "com.remission.transmission.ui-testing"
        }
    }

    var trustKeychainServiceIdentifier: String {
        switch self {
        case .release:
            return "com.remission.transmission.trust"
        case .development:
            return "com.remission.transmission.trust.dev"
        case .unitTesting(let id):
            return "com.remission.transmission.trust.test-\(id.uuidString)"
        case .uiTesting:
            return "com.remission.transmission.trust.ui-testing"
        }
    }

    func userDefaults() -> UserDefaults {
        guard let suiteName = userDefaultsSuiteName,
            let defaults = UserDefaults(suiteName: suiteName)
        else {
            return .standard
        }
        return defaults
    }
}
