import SwiftUI

struct AppSectionCard<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title.isEmpty == false {
                Text(title)
                    .font(.headline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(12)
            .appCardSurface(cornerRadius: 14)

            if let footer, footer.isEmpty == false {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
