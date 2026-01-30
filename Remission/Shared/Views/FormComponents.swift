import SwiftUI

/// Стандартный стиль для текстовых полей в формах приложения.
@MainActor
struct AppFormFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .appPillSurface()
    }
}

extension TextFieldStyle where Self == AppFormFieldStyle {
    static var appFormField: AppFormFieldStyle { .init() }
}

/// Ключ для передачи ширины лейблов вверх по иерархии.
struct LabelWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [CGFloat] = []
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        value.append(contentsOf: nextValue())
    }
}

/// Универсальная строка формы с меткой и контентом.
@MainActor
struct AppFormField<Content: View>: View {
    let label: String
    let labelWidth: CGFloat?
    @ViewBuilder let content: () -> Content

    init(
        _ label: String,
        labelWidth: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: LabelWidthPreferenceKey.self,
                            value: [geometry.size.width]
                        )
                    }
                )
                .frame(width: labelWidth, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Input Filtering Helpers

extension String {
    /// Оставляет только разрешенные символы в строке.
    func filtered(allowed: CharacterSet) -> String {
        String(unicodeScalars.filter { allowed.contains($0) })
    }

    /// Оставляет только ASCII и разрешенные символы.
    func filteredASCII(allowed: CharacterSet) -> String {
        String(unicodeScalars.filter { $0.isASCII && allowed.contains($0) })
    }
}

extension Binding where Value == String {
    /// Создает привязку с автоматической фильтрацией ввода.
    func filtered(allowed: CharacterSet) -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0.filtered(allowed: allowed) }
        )
    }

    /// Создает привязку с фильтрацией ASCII символов.
    func filteredASCII(allowed: CharacterSet) -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0.filteredASCII(allowed: allowed) }
        )
    }
}
