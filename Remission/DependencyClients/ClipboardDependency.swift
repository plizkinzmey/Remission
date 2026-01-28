import Foundation

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(AppKit)
    import AppKit
#endif

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros

    /// Клиент для копирования текста в буфер обмена (iOS/macOS), пригоден для моков в тестах.
    @DependencyClient
    struct ClipboardClient: Sendable {
        var copy: @Sendable (String) async -> Void = { _ in }
    }

    extension ClipboardClient {
        static let live: ClipboardClient = ClipboardClient { value in
            #if os(iOS) || os(tvOS) || os(visionOS)
                await MainActor.run {
                    UIPasteboard.general.string = value
                }
            #elseif os(macOS)
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(value, forType: .string)
                }
            #else
                _ = value  // Платформа без поддержки copy, оставляем no-op.
            #endif
        }
    }

    extension ClipboardClient: DependencyKey {
        static let liveValue: ClipboardClient = .live
        static let previewValue: ClipboardClient = ClipboardClient(copy: { _ in })
        static let testValue: ClipboardClient = ClipboardClient(copy: { _ in })
    }

    extension DependencyValues {
        var clipboard: ClipboardClient {
            get { self[ClipboardClient.self] }
            set { self[ClipboardClient.self] = newValue }
        }
    }
#endif
