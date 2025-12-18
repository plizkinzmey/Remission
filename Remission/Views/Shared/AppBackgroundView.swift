import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.Background.baseGradient(colorScheme)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppTheme.Background.glowColor(colorScheme)
                            .opacity(AppTheme.Background.glowOpacity(colorScheme)),
                        .clear
                    ],
                    center: UnitPoint(x: 0.82, y: 0.20),
                    startRadius: 12,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.78
                )
                .blendMode(colorScheme == .dark ? .screen : .plusLighter)
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppTheme.Background.glowColor(colorScheme)
                            .opacity(AppTheme.Background.glowOpacity(colorScheme) * 0.65),
                        .clear
                    ],
                    center: UnitPoint(x: 0.12, y: 0.92),
                    startRadius: 12,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.62
                )
                .blendMode(colorScheme == .dark ? .screen : .plusLighter)
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.34 : 0.08),
                        Color.black.opacity(0.0),
                        Color.black.opacity(colorScheme == .dark ? 0.44 : 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
                .ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
    }
}
