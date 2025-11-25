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
                Button(L10n.tr("torrentDetail.error.close"), action: onDismiss)
                    .buttonStyle(.bordered)
            }
        } label: {
            Text(L10n.tr("torrentDetail.error.title"))
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
