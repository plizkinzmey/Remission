import SwiftUI

extension View {
    func appRootChrome() -> some View {
        self
            .tint(AppTheme.accent)
            .background(AppBackgroundView())
    }

    func appCardSurface(cornerRadius: CGFloat = 14) -> some View {
        modifier(AppCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func appPillSurface() -> some View {
        modifier(AppPillSurfaceModifier())
    }
}

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
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
            .shadow(color: AppTheme.Shadow.card(colorScheme), radius: 14, x: 0, y: 10)
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
        #if os(visionOS)
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        #else
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .glassEffect(
                    .regular
                        .tint(AppTheme.Glass.tint(colorScheme))
                        .interactive(true),
                    in: Capsule(style: .continuous)
                )
        #endif
    }
}
