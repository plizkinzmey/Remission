import SwiftUI

struct TorrentErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        GroupBox {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                Spacer()
                Button("Закрыть", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        } label: {
            Text("Ошибка")
                .font(.headline)
                .foregroundStyle(.red)
        }
    }
}

#if DEBUG
    #Preview {
        TorrentErrorView(message: "Не удалось загрузить торренты") {}
            .padding()
    }
#endif
