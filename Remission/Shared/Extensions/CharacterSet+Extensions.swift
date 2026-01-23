import Foundation

extension CharacterSet {
    /// Символы, допустимые в имени хоста или IP-адресе.
    static let hostCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: ".-")
        return set
    }()

    /// Символы, допустимые в пути (Transmission RPC path).
    static let pathCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "/-_")
        return set
    }()
}
