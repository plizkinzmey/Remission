import Foundation

extension CharacterSet {
    /// Символы, допустимые в дружественном имени сервера (включает кириллицу, пробелы, цифры, дефис, точку, скобки).
    static let serverNameCharacters: CharacterSet = {
        var set = CharacterSet.letters
        set.formUnion(.decimalDigits)
        set.insert(charactersIn: " -._()[]")
        return set
    }()

    /// Символы, допустимые в имени хоста или IP-адресе. Строго ASCII буквы/цифры + точки, дефисы и IPv6 двоеточие/скобки.
    static let hostCharacters: CharacterSet = {
        var set = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: ".-:[]")
        return set
    }()

    /// Символы, допустимые в пути (Transmission RPC path). Строго ASCII буквы/цифры + спецсимволы пути.
    static let pathCharacters: CharacterSet = {
        var set = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: "/-_~%?&=+:@")
        return set
    }()

    /// Символы, допустимые в имени пользователя. ASCII буквы/цифры + символы почты/системных имен.
    static let usernameCharacters: CharacterSet = {
        var set = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        set.insert(charactersIn: "@_.-+")
        return set
    }()

    /// Символы, допустимые в пароле. Любые печатные ASCII символы (без кириллицы).
    static let passwordCharacters: CharacterSet = {
        return CharacterSet(charactersIn: UnicodeScalar(32)...UnicodeScalar(126))
    }()
}
