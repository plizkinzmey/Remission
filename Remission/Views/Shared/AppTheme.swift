import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.20, green: 0.56, blue: 1.00)

    enum Stroke {
        static func subtle(_ colorScheme: ColorScheme) -> Color {
            switch colorScheme {
            case .dark: return Color.white.opacity(0.12)
            case .light: return Color.black.opacity(0.14)
            @unknown default: return Color.white.opacity(0.12)
            }
        }
    }

    enum Shadow {
        static func card(_ colorScheme: ColorScheme) -> Color {
            switch colorScheme {
            case .dark: return Color.black.opacity(0.28)
            case .light: return Color.black.opacity(0.12)
            @unknown default: return Color.black.opacity(0.18)
            }
        }
    }

    enum Background {
        static func baseGradient(_ colorScheme: ColorScheme) -> LinearGradient {
            switch colorScheme {
            case .dark:
                return LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.18, blue: 0.22),
                        Color(red: 0.03, green: 0.07, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .light:
                return LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.00),
                        Color(red: 0.90, green: 0.95, blue: 0.98),
                        Color(red: 0.96, green: 0.98, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            @unknown default:
                return baseGradient(.dark)
            }
        }

        static func glowColor(_ colorScheme: ColorScheme) -> Color {
            switch colorScheme {
            case .dark: return Color(red: 0.20, green: 0.90, blue: 0.80)
            case .light: return Color(red: 0.12, green: 0.62, blue: 0.68)
            @unknown default: return Color(red: 0.20, green: 0.90, blue: 0.80)
            }
        }

        static func glowOpacity(_ colorScheme: ColorScheme) -> Double {
            switch colorScheme {
            case .dark: return 0.26
            case .light: return 0.18
            @unknown default: return 0.26
            }
        }
    }

    enum Glass {
        static func tint(_ colorScheme: ColorScheme) -> Color {
            switch colorScheme {
            case .dark:
                return AppTheme.accent.opacity(0.55)
            case .light:
                return AppTheme.accent.opacity(0.30)
            @unknown default:
                return AppTheme.accent.opacity(0.55)
            }
        }
    }
}
