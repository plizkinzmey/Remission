import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @Binding var showingDeleteConfirmation: Bool

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton(
                        title: isActive ? "Пауза" : "Старт",
                        systemImage: isActive ? "pause.fill" : "play.fill",
                        color: isActive ? .orange : .green
                    ) {
                        store.send(isActive ? .stopTorrent : .startTorrent)
                    }

                    actionButton(
                        title: "Проверить",
                        systemImage: "checkmark.shield.fill",
                        color: .blue
                    ) {
                        store.send(.verifyTorrent)
                    }
                }

                actionButton(
                    title: "Удалить торрент",
                    systemImage: "trash.fill",
                    color: .red,
                    fullWidth: true
                ) {
                    showingDeleteConfirmation = true
                }
            }
        } label: {
            Text("Действия")
                .font(.headline)
        }
    }

    private var isActive: Bool {
        store.status == 4 || store.status == 6
    }

    private func actionButton(
        title: String,
        systemImage: String,
        color: Color,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}

#if DEBUG
    struct TorrentActionsViewPreviewContainer: View {
        @State private var showingDelete: Bool = false

        var body: some View {
            TorrentActionsView(
                store: Store(
                    initialState: TorrentDetailState(torrentId: 1),
                    reducer: { TorrentDetailReducer() }
                ),
                showingDeleteConfirmation: $showingDelete
            )
        }
    }

    #Preview {
        TorrentActionsViewPreviewContainer()
            .padding()
    }
#endif
