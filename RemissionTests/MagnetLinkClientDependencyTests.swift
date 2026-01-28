import Foundation
import Testing

@testable import Remission

@Suite("Magnet Link Client Tests")
struct MagnetLinkClientDependencyTests {
    // Проверяет, что nil вход возвращает nil.
    @Test
    func nilInputReturnsNil() {
        #expect(extractMagnetLink(from: nil) == nil)
    }

    // Проверяет, что пустая или пробельная строка не распознаётся как magnet.
    @Test
    func whitespaceOnlyReturnsNil() {
        #expect(extractMagnetLink(from: "   \n\t ") == nil)
    }

    // Проверяет извлечение magnet-ссылки из строки с лишним текстом.
    @Test
    func extractsMagnetLinkFromText() {
        let value = "Ссылка: magnet:?xt=urn:btih:abcdef1234567890&dn=Ubuntu и ещё текст"

        let result = extractMagnetLink(from: value)

        #expect(result == "magnet:?xt=urn:btih:abcdef1234567890&dn=Ubuntu")
    }

    // Проверяет, что схема magnet распознаётся независимо от регистра.
    @Test
    func schemeIsCaseInsensitive() {
        let value = "MAGNET:?xt=urn:btih:abcdef1234567890&dn=Ubuntu"

        let result = extractMagnetLink(from: value)

        #expect(result == value)
    }

    // Проверяет, что ссылки с неверной схемой не принимаются.
    @Test
    func invalidSchemeReturnsNil() {
        let value = "magnetx:?xt=urn:btih:abcdef1234567890"

        let result = extractMagnetLink(from: value)

        #expect(result == nil)
    }

    // Проверяет, что при нескольких токенах берётся первый магнитный токен.
    @Test
    func extractsFirstMagnetToken() {
        let value = "magnet:?xt=urn:btih:aaa\n magnet:?xt=urn:btih:bbb"

        let result = extractMagnetLink(from: value)

        #expect(result == "magnet:?xt=urn:btih:aaa")
    }
}
