import Foundation
import Testing

@testable import Remission

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

@Suite("Clipboard Dependency Tests")
struct ClipboardDependencyTests {
    // Проверяет, что тестовый клиент copy выполняется без ошибок и не требует платформенных API.
    @Test
    func testValueCopyDoesNotThrow() async {
        let client = ClipboardClient.testValue
        await client.copy("sample")
        #expect(true)
    }

    @Test
    func liveValueCopiesToSystemPasteboard() async {
        let client = ClipboardClient.live
        let textToCopy = "Hello from tests \(UUID().uuidString)"

        await client.copy(textToCopy)

        // Verify pasteboard content if possible
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            let copied = pasteboard.string(forType: .string)
            #expect(copied == textToCopy)
        #elseif os(iOS)
            let pasteboard = UIPasteboard.general
            let copied = pasteboard.string
            #expect(copied == textToCopy)
        #endif
    }
}
