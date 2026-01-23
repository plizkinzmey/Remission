import SwiftUI

/// Унифицированная кнопка действия над торрентом с поддержкой состояния загрузки.
struct AppTorrentActionButton: View {
    let type: TorrentActionType
    let isBusy: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: type.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .opacity(isBusy ? 0 : 1)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(type.tint)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(type.tint)
        .disabled(isBusy || isLocked)
        .accessibilityIdentifier(type.accessibilityIdentifier)
        .accessibilityLabel(type.title)
        .animation(.easeInOut(duration: 0.2), value: isBusy)
        #if os(macOS)
            .help(type.title)
        #endif
    }
}
