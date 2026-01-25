import Foundation
import SwiftUI

extension View {
    /// Применяет корневую стилизацию для ОС 26.0+
    func appRootChrome() -> some View {
        self.tint(Color.accentColor)
    }

    /// Применяет эффект Liquid Glass к карточке.
    func appCardSurface(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        self.glassEffect(
            .regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                // Используем тонкую обводку для четкости границ "стекла"
                .strokeBorder(.quaternary)
        )
    }

    /// Применяет цветной эффект Liquid Glass к карточке (Stained Glass).
    func appTintedCardSurface(
        color: Color,
        opacity: Double = 0.1,
        cornerRadius: CGFloat = AppTheme.Radius.card
    ) -> some View {
        self.background(
            color.opacity(opacity),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .glassEffect(
            .regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(0.25))
        )
    }

    /// Применяет эффект Liquid Glass к капсуле.
    func appPillSurface() -> some View {
        self.glassEffect(.regular, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(.quaternary)
            )
    }

    /// Применяет цветной эффект Liquid Glass к капсуле (Stained Glass).
    func appTintedPillSurface(color: Color, opacity: Double = 0.1) -> some View {
        self.background(color.opacity(opacity), in: Capsule(style: .continuous))
            .glassEffect(.regular, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(0.25))
            )
    }

    /// Специальный стиль для кнопок в тулбаре.
    func appToolbarPillSurface() -> some View {
        self.glassEffect(.regular, in: Capsule(style: .continuous))
    }

    /// Применяет стандартный стиль для подписей.
    func appCaption() -> some View {
        self.font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Применяет моноширинное начертание для цифр (полезно для счетчиков и скоростей).
    func appMonospacedDigit() -> some View {
        self.monospacedDigit()
    }

    /// Анимирует появление элемента через материализацию стекла (OS 26+).
    func appMaterialize() -> some View {
        self.glassEffectTransition(AppTheme.Liquid.transition)
    }
}

#if os(visionOS)
    // Заглушки для совместимости, если потребуются
#endif
