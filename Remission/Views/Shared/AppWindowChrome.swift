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

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .appCardSurface(cornerRadius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
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
            return colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.06)
        case .accent:
            return AppTheme.accent.opacity(colorScheme == .dark ? 0.45 : 0.30)
        case .success:
            return Color.green.opacity(colorScheme == .dark ? 0.40 : 0.26)
        case .error:
            return Color.red.opacity(colorScheme == .dark ? 0.38 : 0.24)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .neutral:
            return colorScheme == .dark ? .white : .black
        case .accent:
            return .white
        case .success:
            return .white
        case .error:
            return .white
        }
    }
}
