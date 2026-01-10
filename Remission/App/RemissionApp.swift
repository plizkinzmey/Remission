import ComposableArchitecture
import Foundation
import SwiftUI

/// Временная фабрика конфигурации TransmissionClient. До появления onboarding
/// возвращает тестовую локальную конфигурацию.
enum TransmissionClientBootstrap {}

@main
struct RemissionApp: App {
    @StateObject var store: StoreOf<AppReducer>
    #if os(macOS)
        @NSApplicationDelegateAdaptor(RemissionAppDelegate.self) var appDelegate
    #endif

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let scenario = AppBootstrap.parseUITestScenario(arguments: arguments)
        let fixture = AppBootstrap.parseUITestFixture(arguments: arguments)
        let initialState = AppBootstrap.makeInitialState(arguments: arguments)

        let store = Store(initialState: initialState) {
            AppReducer()
        } withDependencies: { dependencies in
            if scenario != nil || fixture != nil {
                dependencies = AppDependencies.makeUITest(
                    fixture: fixture,
                    scenario: scenario,
                    environment: ProcessInfo.processInfo.environment
                )
            } else {
                dependencies = AppDependencies.makeLive()
            }
        }

        _store = StateObject(wrappedValue: store)
        #if os(macOS)
            RemissionAppDelegate.appStore = store
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                // Защитный минимальный размер для macOS, чтобы верстка не схлопывалась.
                #if os(macOS)
                    .frame(
                        minWidth: WindowConstants.minimumSize.width,
                        minHeight: WindowConstants.minimumSize.height)
                #endif
        }
        #if os(macOS)
            .defaultSize(
                width: WindowConstants.minimumSize.width,
                height: WindowConstants.minimumSize.height
            )
            // Важно: .contentSize заставляет окно "подгоняться" под контент при навигации,
            // из-за чего размер прыгает между экранами. Нам нужен стабильный размер окна.
            .windowResizability(.contentMinSize)
        #endif
    }
}

extension TransmissionClientBootstrap {
    static func makeLiveDependency(
        dependencies: DependencyValues
    ) -> TransmissionClientDependency {
        let logger = dependencies.appLogger.withCategory("bootstrap")
        logger.debug("Начало инициализации live dependency TransmissionClient.")
        guard
            let config = makeConfig(
                credentialsStore: dependencies.keychainCredentials,
                appLogger: dependencies.appLogger.withCategory("bootstrap.transmission")
            )
        else {
            logger.warning("Конфигурация TransmissionClient недоступна, используем placeholder.")
            return TransmissionClientDependency.placeholder
        }

        let appClock = dependencies[keyPath: \.appClock]
        let client = TransmissionClient(config: config, clock: appClock.clock())
        #if canImport(ComposableArchitecture)
            let trustPromptCenter = dependencies.transmissionTrustPromptCenter
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())
        #endif
        let dependency = TransmissionClientDependency.live(client: client)
        logger.debug("Успешно создан live dependency TransmissionClient для \(config.baseURL)")
        return dependency
    }

    static func makeConfig(
        credentialsStore: KeychainCredentialsDependency,
        appLogger: AppLogger,
        fileURL: URL = ServerConfigStoragePaths.defaultURL()
    ) -> TransmissionClientConfig? {
        let records = ServerConfigStoragePaths.loadSnapshot(fileURL: fileURL)
        guard let record = mostRecentRecord(in: records) else {
            return nil
        }

        let mapper = TransmissionDomainMapper()
        guard let server = try? mapper.mapServerConfig(record: record, credentials: nil) else {
            appLogger.error("Не удалось преобразовать сохранённую конфигурацию сервера.")
            return nil
        }

        let password: String? = {
            guard let credentialsKey = server.credentialsKey else { return nil }
            do {
                return try credentialsStore.load(credentialsKey)?.password
            } catch {
                appLogger.error(
                    "Не удалось загрузить пароль из Keychain: \(error.localizedDescription)")
                return nil
            }
        }()

        let loggerContext = TransmissionLogContext(
            serverID: server.id,
            host: server.connection.host,
            path: server.connection.path
        )
        return server.makeTransmissionClientConfig(
            password: password,
            network: .default,
            logger: DefaultTransmissionLogger(
                appLogger: appLogger,
                baseContext: loggerContext
            )
        )
    }

    private static func mostRecentRecord(
        in records: [StoredServerConfigRecord]
    ) -> StoredServerConfigRecord? {
        records.sorted { lhs, rhs in
            (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
        .first
    }
}

#if os(macOS)
    import AppKit

    private enum WindowConstants {
        // Минимальный размер окна, чтобы таблицы и панели не схлопывались.
        // Bump the minimum width so modal/Settings sheets can be presented without
        // forcing scroll content on smaller main windows. This keeps the app
        // visually balanced and avoids cramped dialogs.
        static let minimumSize = NSSize(width: 1100, height: 640)
    }

    @MainActor
    final class RemissionAppDelegate: NSObject, NSApplicationDelegate {
        static var appStore: StoreOf<AppReducer>?
        private var openFilesObserver: NSObjectProtocol?

        func applicationDidFinishLaunching(_ notification: Notification) {
            Task { @MainActor in
                let isUITesting = ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    window.contentMinSize = WindowConstants.minimumSize
                    window.makeKeyAndOrderFront(nil)
                }
                registerOpenFilesObserver()
                if isUITesting == false {
                    applyInitialPresentationIfNeeded()
                }
            }
        }

        @MainActor
        private func shouldApplyInitialPresentation(_ window: NSWindow) -> Bool {
            let size = window.frame.size
            let epsilon: CGFloat = 1
            return abs(size.width - WindowConstants.minimumSize.width) <= epsilon
                && abs(size.height - WindowConstants.minimumSize.height) <= epsilon
        }

        @MainActor
        private func applyInitialPresentationIfNeeded() {
            guard let window = preferredMainWindow() else { return }

            let shouldApplyInitialPresentation =
                window.isZoomed == false
                && window.isMiniaturized == false
                && shouldApplyInitialPresentation(window)

            guard shouldApplyInitialPresentation else { return }

            window.collectionBehavior.insert(.fullScreenPrimary)

            if window.styleMask.contains(.fullScreen) == false {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard window.styleMask.contains(.fullScreen) == false else { return }
                    window.toggleFullScreen(nil)
                }
            }
        }

        @MainActor
        private func preferredMainWindow() -> NSWindow? {
            if let window = NSApp.mainWindow {
                return window
            }
            if let window = NSApp.keyWindow {
                return window
            }
            return NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first
        }

        func application(_ sender: NSApplication, openFile filename: String) -> Bool {
            if forwardOpenToRunningInstance(urls: [URL(fileURLWithPath: filename)]) {
                sender.terminate(nil)
                return true
            }
            handleOpen(urls: [URL(fileURLWithPath: filename)])
            return true
        }

        func application(_ sender: NSApplication, openFiles filenames: [String]) {
            let urls = filenames.map { URL(fileURLWithPath: $0) }
            if forwardOpenToRunningInstance(urls: urls) {
                sender.reply(toOpenOrPrint: .success)
                sender.terminate(nil)
                return
            }
            handleOpen(urls: urls)
            sender.reply(toOpenOrPrint: .success)
        }

        private func registerOpenFilesObserver() {
            let center = DistributedNotificationCenter.default()
            let notificationName = OpenFilesNotification.name
            let pathsKey = OpenFilesNotification.pathsKey
            let senderKey = OpenFilesNotification.senderKey
            openFilesObserver = center.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                guard let userInfo = notification.userInfo else { return }
                guard let senderPID = userInfo[senderKey] as? Int else { return }
                if senderPID == ProcessInfo.processInfo.processIdentifier {
                    return
                }
                guard let paths = userInfo[pathsKey] as? [String] else { return }
                let urls = paths.map { URL(fileURLWithPath: $0) }
                Task { @MainActor in
                    self.handleOpen(urls: urls)
                }
            }
        }

        private func forwardOpenToRunningInstance(urls: [URL]) -> Bool {
            guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
                return false
            }
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let otherInstance = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            )
            .first(where: { $0.processIdentifier != currentPID })
            guard let target = otherInstance else { return false }

            let center = DistributedNotificationCenter.default()
            center.post(
                name: OpenFilesNotification.name,
                object: nil,
                userInfo: [
                    OpenFilesNotification.pathsKey: urls.map(\.path),
                    OpenFilesNotification.senderKey: currentPID
                ]
            )
            target.activate(options: [.activateAllWindows])
            return true
        }

        private func handleOpen(urls: [URL]) {
            guard let store = Self.appStore else { return }
            for url in urls {
                store.send(.openTorrentFile(url))
            }
        }

    }

    private enum OpenFilesNotification {
        static let name = Notification.Name("RemissionOpenFilesNotification")
        static let pathsKey = "paths"
        static let senderKey = "senderPID"
    }
#endif
