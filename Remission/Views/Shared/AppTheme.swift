import SwiftUI

/// Стандарты визуальной системы Remission для Apple OS 26.0+ (Liquid Glass Era).
enum AppTheme {
    /// Системный акцент.
    static let accent = Color.accentColor

    /// Новая секция для управления эффектами Liquid Glass.
    enum Liquid {
        /// Стандартный вариант жидкого стекла.
        static let glass = Glass.regular

        /// Эффект материализации для появления элементов.
        static let transition = GlassEffectTransition.materialize
    }

    enum Radius {
        static let card: CGFloat = 14
        static let modal: CGFloat = 20
        static let pill: CGFloat = 100
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
        static let section: CGFloat = 24
    }
}
