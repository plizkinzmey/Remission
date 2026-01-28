import Foundation
import Testing

@testable import Remission

@Suite("Storage Formatters Tests")
struct StorageFormattersTests {
    // Этот тест фиксирует ключевой контракт обёртки:
    // StorageFormatters.bytes(...) должен полностью совпадать
    // с TorrentDataFormatter.bytes(...), без дополнительной логики.
    // Мы проверяем несколько значений, чтобы защититься от случайных
    // изменений в будущем (например, если кто-то решит «подправить» формат).
    @Test(
        "Storage bytes formatter delegates to TorrentDataFormatter",
        arguments: [
            Int64(0),
            Int64(1_024),
            Int64(5_000_000)
        ]
    )
    func bytesDelegatesToTorrentFormatter(_ value: Int64) {
        let expected = TorrentDataFormatter.bytes(value)
        let actual = StorageFormatters.bytes(value)

        #expect(actual == expected)
    }
}
