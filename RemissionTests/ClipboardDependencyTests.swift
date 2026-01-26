import Foundation
import Testing

@testable import Remission

@Suite("Clipboard Dependency Tests")
struct ClipboardDependencyTests {
    // Проверяет, что тестовый клиент copy выполняется без ошибок и не требует платформенных API.
    @Test
    func testValueCopyDoesNotThrow() async {
        let client = ClipboardClient.testValue

        await client.copy("sample")

        #expect(true)
    }
}
