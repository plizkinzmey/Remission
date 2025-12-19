import SwiftUI

struct AppSectionCard<Content: View>: View {
    enum Style {
        case card
        case plain
    }

    let title: String
    let footer: String?
    let style: Style
    @ViewBuilder let content: Content

    init(
        _ title: String,
        footer: String? = nil,
        style: Style = .card,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.style = style
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title.isEmpty == false {
                Text(title)
                    .font(.headline.weight(.semibold))
            }

            contentContainer

            if let footer, footer.isEmpty == false {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var contentContainer: some View {
        let contentStack = VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(12)

        switch style {
        case .card:
            contentStack.appCardSurface(cornerRadius: 14)
        case .plain:
            contentStack
        }
    }
}
