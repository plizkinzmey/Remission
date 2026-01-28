import Foundation
import Testing

@testable import Remission

@Suite("Transmission Path Normalization Tests")
struct TransmissionPathNormalizationTests {
    // Этот тест фиксирует поведение «без базы»: если сервер не сообщил
    // стандартную директорию загрузки, мы не имеем права что-то склеивать.
    // В этом случае функция должна вернуть исходный ввод как есть.
    @Test("Returns destination as-is when base directory is empty")
    func returnsDestinationWhenBaseIsEmpty() {
        let result = TransmissionPathNormalization.normalize(
            "custom/path",
            defaultDownloadDirectory: "   "
        )

        #expect(result == "custom/path")
    }

    // Этот тест описывает обратный случай: пользователь не ввёл путь,
    // поэтому мы должны использовать базовую директорию сервера.
    @Test("Returns base directory when destination is empty")
    func returnsBaseWhenDestinationIsEmpty() {
        let result = TransmissionPathNormalization.normalize(
            "   ",
            defaultDownloadDirectory: "/downloads"
        )

        #expect(result == "/downloads")
    }

    // Этот тест проверяет ключевую эвристику: если путь уже явно «вложенный абсолютный»
    // (например, `/volume/downloads`), мы не должны его менять или присоединять к базе.
    @Test("Keeps nested absolute paths unchanged")
    func keepsNestedAbsolutePath() {
        let result = TransmissionPathNormalization.normalize(
            "/volume/downloads",
            defaultDownloadDirectory: "/base"
        )

        #expect(result == "/volume/downloads")
    }

    // Этот тест фиксирует нестандартное, но важное поведение:
    // короткий путь вида `/movies` НЕ считается полноценным абсолютным путём
    // и трактуется как имя подпапки. Мы ожидаем склейку с базой.
    @Test("Treats single-component absolute path as a folder name")
    func treatsSingleComponentAbsoluteAsComponent() {
        let result = TransmissionPathNormalization.normalize(
            "/movies",
            defaultDownloadDirectory: "/downloads"
        )

        #expect(result == "/downloads/movies")
    }

    // Этот тест проверяет, что функция корректно чистит лишние пробелы и слеши,
    // а также аккуратно работает с базой, у которой уже есть завершающий `/`.
    @Test("Trims whitespace and slashes on both base and destination")
    func trimsWhitespaceAndSlashes() {
        let result = TransmissionPathNormalization.normalize(
            "  /movies/  ",
            defaultDownloadDirectory: "/downloads/"
        )

        #expect(result == "/downloads/movies")
    }

    // Этот тест покрывает крайний случай, когда пользователь ввёл только слеши.
    // После обрезки компонентов путь становится пустым, и мы должны вернуть базу.
    @Test("Returns base when destination contains only slashes")
    func returnsBaseWhenDestinationIsOnlySlashes() {
        let result = TransmissionPathNormalization.normalize(
            "///",
            defaultDownloadDirectory: "/downloads"
        )

        #expect(result == "/downloads")
    }
}
