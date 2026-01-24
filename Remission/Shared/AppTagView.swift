import SwiftUI

/// Универсальный компонент для отображения тегов, категорий и статусов в виде плашек.
struct AppTagView: View {
    let text: String
    var color: Color = .primary
    var opacity: Double = 0.08

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                Capsule()
                    .fill(color.opacity(opacity))
            )
            .foregroundStyle(color)
    }
}

#if DEBUG
    #Preview {
        HStack {
            AppTagView(text: "ISO")
            AppTagView(text: "Downloading", color: .blue)
            AppTagView(text: "Seeding", color: .green)
            AppTagView(text: "Paused", color: .secondary)
        }
        .padding()
    }
#endif
