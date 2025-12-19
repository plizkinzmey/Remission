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
