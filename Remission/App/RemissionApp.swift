import ComposableArchitecture
import Foundation
import SwiftUI

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

#if os(macOS)
    import AppKit

    private enum WindowConstants {
        // Минимальный размер окна, чтобы таблицы и панели не схлопывались.
        // Reduced to support macOS Split View (half-screen snapping).
        // Previous value (1100) prevented snapping on standard displays.
        static let minimumSize = NSSize(width: 600, height: 450)
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
