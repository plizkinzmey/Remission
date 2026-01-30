import SwiftUI

struct AppStatusCardView: View {
    let systemImage: String
    let title: String
    let message: String
    var buttonTitle: String?
    var onButtonTap: (() -> Void)?
    var iconColor: Color = .secondary

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(iconColor)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            if let buttonTitle, let onButtonTap {
                Button(action: onButtonTap) {
                    Text(buttonTitle)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .appCardSurface()
    }
}

#if DEBUG
    #Preview {
        ZStack {
            AppBackgroundView()
            AppStatusCardView(
                systemImage: "wifi.slash",
                title: "Нет подключения",
                message:
                    "Не удалось соединиться с сервером. Проверьте настройки сети или адрес сервера.",
                buttonTitle: "Повторить",
                onButtonTap: {},
                iconColor: .orange
            )
        }
    }
#endif
