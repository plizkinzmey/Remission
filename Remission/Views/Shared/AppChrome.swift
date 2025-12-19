import Foundation
import SwiftUI

extension View {
    func appRootChrome() -> some View {
        modifier(AppRootChromeModifier())
    }

    func appCardSurface(cornerRadius: CGFloat = 14, showsShadow: Bool = true) -> some View {
        modifier(AppCardSurfaceModifier(cornerRadius: cornerRadius, showsShadow: showsShadow))
    }

    func appPillSurface() -> some View {
        modifier(AppPillSurfaceModifier())
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
    let showsShadow: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppTheme.Glass.tint(colorScheme))
                            .opacity(colorScheme == .dark ? 0.12 : 0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
            .shadow(
                color: showsShadow ? AppTheme.Shadow.card(colorScheme) : .clear,
                radius: showsShadow ? 14 : 0,
                x: 0,
                y: showsShadow ? 10 : 0
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
                    .opacity(colorScheme == .dark ? 0.10 : 0.06)
            )
    }
}
