import Foundation
import Testing

@testable import Remission

@Suite("Torrent Data Formatter Tests")
struct TorrentDataFormatterTests {
    // Этот тест проверяет базовый инвариант форматирования байт:
    // результат должен быть непустым и содержать единицы измерения.
    // Мы сознательно не фиксируем точную строку, потому что ByteCountFormatter
    // зависит от локали и может слегка отличаться на разных машинах.
    @Test("Bytes formatting returns a non-empty value with units")
    func bytesFormattingIsNonEmpty() {
        let formatted = TorrentDataFormatter.bytes(1_024)

        #expect(formatted.isEmpty == false)
        #expect(formatted.contains("Б") || formatted.contains("B"))
    }

    // Этот тест фиксирует контракт для нулевой скорости:
    // при bytesPerSecond <= 0 мы должны показывать стабильное значение "0 Б/с",
    // а не пытаться форматировать отрицательные числа.
    @Test("Speed formatting clamps non-positive values to zero")
    func speedClampsNonPositiveValues() {
        #expect(TorrentDataFormatter.speed(0) == "0 Б/с")
        #expect(TorrentDataFormatter.speed(-10) == "0 Б/с")
    }

    // Этот тест проверяет, что для положительной скорости мы действительно
    // используем форматирование байт и добавляем суффикс "/с".
    // Здесь мы сравниваем с тем же bytes(...), чтобы тест оставался
    // устойчивым к изменениям локали.
    @Test("Speed formatting uses bytes formatter and appends suffix")
    func speedUsesBytesFormatter() {
        let value = 2_048
        let expected = "\(TorrentDataFormatter.bytes(Int64(value)))/с"

        #expect(TorrentDataFormatter.speed(value) == expected)
    }

    // Этот тест фиксирует поведение для ETA < 0:
    // такие значения Transmission обычно трактует как «неизвестно»,
    // и мы должны вернуть локализованный плейсхолдер.
    @Test("ETA uses placeholder for negative values")
    func etaUsesPlaceholderForNegativeValues() {
        let placeholder = L10n.tr("torrentDetail.eta.placeholder")
        let formatted = TorrentDataFormatter.eta(-1)

        #expect(formatted == placeholder)
    }

    // Этот тест покрывает явный крайний случай:
    // для ETA == 0 мы возвращаем короткую стабильную строку "0с".
    @Test("ETA returns zero seconds for empty duration")
    func etaReturnsZeroSeconds() {
        #expect(TorrentDataFormatter.eta(0) == "0с")
    }

    // Этот тест проверяет «живой» сценарий ETA > 0.
    // Из-за локализации DateComponentsFormatter мы не фиксируем точную строку,
    // но требуем, чтобы она:
    // 1) не была плейсхолдером,
    // 2) была непустой.
    @Test("ETA returns a non-empty localized value for positive duration")
    func etaReturnsNonEmptyValue() {
        let placeholder = L10n.tr("torrentDetail.eta.placeholder")
        let formatted = TorrentDataFormatter.eta(90)

        #expect(formatted.isEmpty == false)
        #expect(formatted != placeholder)
    }

    // Этот тест фиксирует ключевую защиту progress(...):
    // значение должно быть зажато в диапазоне [0, 1].
    // Мы проверяем три точки: ниже нуля, внутри диапазона, выше единицы.
    @Test(
        "Progress is clamped to the 0...1 range",
        arguments: [
            (input: -0.2, expected: "0.0%"),
            (input: 0.456, expected: "45.6%"),
            (input: 1.7, expected: "100.0%")
        ]
    )
    func progressIsClamped(input: (input: Double, expected: String)) {
        #expect(TorrentDataFormatter.progress(input.input) == input.expected)
    }
}
