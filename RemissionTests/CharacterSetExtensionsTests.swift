import Foundation
import Testing

@testable import Remission

@Suite("Character Set Extensions Tests")
struct CharacterSetExtensionsTests {
    // Проверяет, что hostCharacters включает допустимые символы хоста.
    @Test
    func hostCharactersContainExpectedSymbols() {
        let set = CharacterSet.hostCharacters
        #expect(set.contains("a".unicodeScalars.first!))
        #expect(set.contains("Z".unicodeScalars.first!))
        #expect(set.contains("1".unicodeScalars.first!))
        #expect(set.contains(".".unicodeScalars.first!))
        #expect(set.contains("-".unicodeScalars.first!))
        #expect(set.contains("/".unicodeScalars.first!) == false)
    }

    // Проверяет, что pathCharacters включает ожидаемые символы пути.
    @Test
    func pathCharactersContainExpectedSymbols() {
        let set = CharacterSet.pathCharacters
        #expect(set.contains("a".unicodeScalars.first!))
        #expect(set.contains("9".unicodeScalars.first!))
        #expect(set.contains("/".unicodeScalars.first!))
        #expect(set.contains("-".unicodeScalars.first!))
        #expect(set.contains("_".unicodeScalars.first!))
        #expect(set.contains(".".unicodeScalars.first!) == false)
    }
}
