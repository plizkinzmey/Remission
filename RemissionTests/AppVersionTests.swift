import Foundation
import Testing

@testable import Remission

@Suite("App Version Tests")
struct AppVersionTests {
    // Проверяет, что shortLabel всегда возвращает непустую строку.
    @Test
    func shortLabelIsNeverEmpty() {
        #expect(AppVersion.shortLabel.isEmpty == false)
    }

    // Проверяет, что footerText содержит shortLabel, чтобы версия
    // всегда была видна в футере приложения.
    @Test
    func footerTextContainsShortLabel() {
        let label = AppVersion.shortLabel
        let footer = AppVersion.footerText
        #expect(footer.contains(label))
    }
}
