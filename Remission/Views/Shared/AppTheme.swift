import SwiftUI

enum AppTheme {
    /// Стандартный системный акцентный цвет.
    static let accent = Color.accentColor

    enum Stroke {
        static func subtle(_ colorScheme: ColorScheme) -> Color {
            // Системный цвет разделителя/границы
            #if os(macOS)
                return Color(nsColor: .separatorColor)
            #else
                return Color(uiColor: .separator)
            #endif
        }
    }

    enum Shadow {
        static func card(_ colorScheme: ColorScheme) -> Color {
            return Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1)
        }
    }

    enum Background {
        static func baseGradient(_ colorScheme: ColorScheme) -> Color {
            // Возвращаем системный фон вместо градиента
            #if os(macOS)
                return Color(nsColor: .windowBackgroundColor)
            #else
                return Color(uiColor: .systemBackground)
            #endif
        }

        static func glowColor(_ colorScheme: ColorScheme) -> Color {
            return .clear
        }

        static func glowOpacity(_ colorScheme: ColorScheme) -> Double {
            return 0
        }
    }

    enum Glass {
        static func tint(_ colorScheme: ColorScheme) -> Color {
            // Убираем тонирование, оставляем нейтральный цвет
            return .clear
        }
    }

    enum Radius {
        static let card: CGFloat = 10  // Более стандартное для системных списков
        static let modal: CGFloat = 12
        static let pill: CGFloat = 100
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
        static let section: CGFloat = 24
    }
}
