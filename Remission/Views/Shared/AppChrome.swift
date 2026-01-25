import Foundation
import SwiftUI

extension View {
    func appRootChrome() -> some View {
        modifier(AppRootChromeModifier())
    }

    func appCardSurface(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        modifier(AppCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func appPillSurface() -> some View {
        modifier(AppPillSurfaceModifier())
    }

    func appToolbarPillSurface() -> some View {
        modifier(AppToolbarPillSurfaceModifier())
    }

    /// Применяет стандартный стиль для подписей и второстепенного текста.
    func appCaption() -> some View {
        self.font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Применяет моноширинное начертание для цифр (полезно для счетчиков и скоростей).
    func appMonospacedDigit() -> some View {
        self.monospacedDigit()
    }
}

#if os(macOS)
    private struct AppRootChromeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                // Используем стандартный акцент и стандартный фон
                .tint(AppTheme.accent)
        }
    }
#else
    private struct AppRootChromeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .tint(AppTheme.accent)
        }
    }
#endif

#if os(visionOS)
    extension View {
        func appGlassEffect<S: Shape>(in _: S) -> some View { self }
        func appGlassEffectTransition() -> some View { self }
    }
#else
    extension View {
        func appGlassEffect<S: Shape>(_ glass: Glass = .regular, in shape: S) -> some View {
            self.glassEffect(glass, in: shape)
        }

        func appGlassEffectTransition(_ transition: GlassEffectTransition) -> some View {
            self.glassEffectTransition(transition)
        }
    }
#endif

private struct AppCardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    // Используем стандартный фон для элементов управления/карточек
                    #if os(macOS)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    #else
                        .fill(Color(uiColor: .secondarySystemBackground))
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
    }
}

private struct AppPillSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                pillBackground
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
    }

    @ViewBuilder
    private var pillBackground: some View {
        Capsule(style: .continuous)
            #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
            #else
                .fill(Color(uiColor: .secondarySystemBackground))
            #endif
    }
}

private struct AppToolbarPillSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(toolbarFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
    }

    private var toolbarFill: Color {
        #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
        #else
            return Color(uiColor: .tertiarySystemBackground)
        #endif
    }
}
