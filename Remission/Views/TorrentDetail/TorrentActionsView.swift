import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton(
                        title: isActive ? "Пауза" : "Старт",
                        systemImage: isActive ? "pause.fill" : "play.fill",
                        color: isActive ? .orange : .green
                    ) {
                        store.send(isActive ? .pauseTapped : .startTapped)
                    }

                    actionButton(
                        title: "Проверить",
                        systemImage: "checkmark.shield.fill",
                        color: .blue
                    ) {
                        store.send(.verifyTapped)
                    }
                }

                actionButton(
                    title: "Удалить торрент",
                    systemImage: "trash.fill",
                    color: .red,
                    fullWidth: true
                ) {
                    store.send(.removeButtonTapped)
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
        var body: some View {
            TorrentActionsView(
                store: Store(
                    initialState: TorrentDetailReducer.State(torrentID: .init(rawValue: 1))
                ) {
                    TorrentDetailReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }

    #Preview {
        TorrentActionsViewPreviewContainer()
            .padding()
    }
#endif
