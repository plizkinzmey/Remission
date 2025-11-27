import SwiftUI

/// Компактный баннер ошибки с опциональной кнопкой повторной попытки.
struct ErrorBannerView: View {
    let message: String
    var onRetry: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if let onRetry {
                Button(L10n.tr("common.retry")) {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("error-banner-retry")
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("error-banner-dismiss")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .accessibilityIdentifier("error-banner")
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 16) {
            ErrorBannerView(
                message: "Не удалось обновить список торрентов",
                onRetry: {},
                onDismiss: {}
            )
            ErrorBannerView(
                message: "Соединение потеряно",
                onRetry: nil,
                onDismiss: {}
            )
        }
        .padding()
    }
#endif
