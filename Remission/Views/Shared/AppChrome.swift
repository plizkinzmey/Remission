import Foundation
import SwiftUI

extension View {
    func appRootChrome() -> some View {
        modifier(AppRootChromeModifier())
    }

    func appCardSurface(cornerRadius: CGFloat = 14) -> some View {
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
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

        private let isUITesting = ProcessInfo.processInfo.environment["UI_TESTING"] == "1"

        func body(content: Content) -> some View {
            content
                .tint(AppTheme.accent)
                .configureMacWindowForTranslucency()
                .containerBackground(Color.clear, for: .window)
                .background(
                    Group {
                        if isUITesting || reduceTransparency {
                            AppBackgroundView()
                        } else {
                            MacWindowBackdropView()
                                .ignoresSafeArea()
                                .overlay(
                                    AppBackgroundView()
                                        .opacity(0.14)
                                        .ignoresSafeArea()
                                )
                        }
                    }
                )
        }
    }
#else
    private struct AppRootChromeModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .tint(AppTheme.accent)
                .background(AppBackgroundView())
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
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.Glass.tint(colorScheme))
                            .opacity(colorScheme == .dark ? 0.12 : 0.10)
                    )
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
            .fill(.regularMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .fill(AppTheme.Glass.tint(colorScheme))
                    .opacity(colorScheme == .dark ? 0.10 : 0.10)
            )
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
    }

    private var toolbarFill: Color {
        #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
        #else
            switch colorScheme {
            case .dark: return Color.black.opacity(0.35)
            case .light: return Color.white.opacity(0.75)
            @unknown default: return Color.black.opacity(0.35)
            }
        #endif
    }
}
