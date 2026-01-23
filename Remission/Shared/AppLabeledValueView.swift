import SwiftUI

/// Универсальный компонент для отображения пар "Метка: Значение".
struct AppLabeledValueView: View {
    enum Layout {
        /// В одну строку (метка слева, значение справа).
        case horizontal
        /// В две строки (метка сверху, значение снизу).
        case vertical
        /// Автоматическое переключение в зависимости от доступного места.
        case adaptive
    }

    let label: String
    let value: String
    var layout: Layout = .adaptive
    var monospacedValue: Bool = false

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                horizontalContent
            case .vertical:
                verticalContent
            case .adaptive:
                ViewThatFits {
                    horizontalContent
                    verticalContent
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: L10n.tr("%@: %@"), locale: Locale.current, label, value))
    }

    private var horizontalContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            labelView
            Spacer(minLength: 8)
            valueView
                .multilineTextAlignment(.trailing)
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            labelView
            valueView
        }
    }

    private var labelView: some View {
        Text(label)
            .appCaption()
    }

    private var valueView: some View {
        Text(value)
            .font(.caption)
            .textSelection(.enabled)
            .modify { view in
                if monospacedValue {
                    view.appMonospacedDigit()
                } else {
                    view
                }
            }
    }
}

extension View {
    @ViewBuilder
    fileprivate func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> Content {
        transform(self)
    }
}
