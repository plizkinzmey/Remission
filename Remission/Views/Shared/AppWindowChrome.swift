import SwiftUI

struct AppWindowHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

struct AppWindowFooterBar<Content: View>: View {
    @ViewBuilder let content: Content
    let contentPadding: CGFloat

    init(contentPadding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.contentPadding = contentPadding
    }

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .padding(.horizontal, AppFooterMetrics.contentInset)
        .padding(.vertical, contentPadding)
        .frame(maxWidth: .infinity)
        .frame(minHeight: AppFooterMetrics.barHeight)
        .appPillSurface()
        .padding(.horizontal, AppFooterMetrics.contentInset)
        .padding(.top, AppFooterMetrics.bottomInset + AppFooterMetrics.capsuleVerticalNudge)
        .padding(
            .bottom,
            max(0, AppFooterMetrics.bottomInset - AppFooterMetrics.capsuleVerticalNudge)
        )
    }
}
struct AppFooterLayout<Content: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, AppFooterMetrics.layoutInset)
                .padding(.top, 12)

            Spacer(minLength: 0)

            AppWindowFooterBar {
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct AppFooterButtonStyle: ButtonStyle {
    enum Variant {
        case neutral
        case accent
        case success
        case error
    }

    @Environment(\.colorScheme) private var colorScheme
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(minHeight: 30)
            .foregroundStyle(foregroundColor)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var backgroundColor: Color {
        switch variant {
        case .neutral:
            return .secondary.opacity(0.12)
        case .accent:
            return AppTheme.accent.opacity(colorScheme == .dark ? 0.35 : 0.25)
        case .success:
            return .green.opacity(colorScheme == .dark ? 0.40 : 0.25)
        case .error:
            return .red.opacity(colorScheme == .dark ? 0.40 : 0.25)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .neutral:
            return .primary
        case .accent:
            return AppTheme.accent
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(minHeight: 30)
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.85))
            .background(
                Capsule(style: .continuous)
                    .fill(primaryFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(primaryStroke)
            )
            .shadow(color: primaryShadow, radius: 6, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var primaryFill: Color {
        if isEnabled {
            return accentFill.opacity(colorScheme == .dark ? 0.75 : 1.0)
        }
        return accentFill.opacity(colorScheme == .dark ? 0.45 : 0.55)
    }

    private var primaryStroke: Color {
        accentFill.opacity(isEnabled ? (colorScheme == .dark ? 0.25 : 0.45) : 0.25)
    }

    private var primaryShadow: Color {
        accentFill.opacity(isEnabled ? (colorScheme == .dark ? 0.35 : 0.25) : 0.0)
    }

    private var accentFill: Color {
        #if os(macOS)
            return Color(nsColor: .controlAccentColor)
        #else
            return AppTheme.accent
        #endif
    }
}
