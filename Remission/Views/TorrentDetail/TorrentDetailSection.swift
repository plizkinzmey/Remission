import SwiftUI

/// Универсальная секция для экрана деталей торрента с поддержкой сворачивания,
/// индикации загрузки и пустых состояний.
struct TorrentDetailSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let hasMetadata: Bool
    let isEmpty: Bool
    let emptyIcon: String
    let emptyTitleLoaded: String
    let emptyTitleLoading: String
    let emptyMessageLoaded: String
    let emptyMessageLoading: String
    let accessibilityIdentifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if isExpanded {
                VStack {
                    if isEmpty {
                        EmptyPlaceholderView(
                            systemImage: emptyIcon,
                            title: hasMetadata ? emptyTitleLoaded : emptyTitleLoading,
                            message: hasMetadata ? emptyMessageLoaded : emptyMessageLoading
                        )
                        .padding(.vertical, 8)
                    } else {
                        content()
                            .padding(.top, 8)
                    }
                }
            }
        } label: {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(title)
                        .font(.body.weight(.medium))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
