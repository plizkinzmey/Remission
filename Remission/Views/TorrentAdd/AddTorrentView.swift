import ComposableArchitecture
import SwiftUI

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Добавление торрента")
                .font(.title3)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Label("Источник", systemImage: "tray.and.arrow.down.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(store.pendingInput.sourceDescription)
                    .font(.body)
                    .bold()
                Text(store.pendingInput.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Закрыть") {
                    store.send(.closeButtonTapped)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    AddTorrentView(
        store: Store(
            initialState: AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .magnetLink(
                        url: URL(string: "magnet:?xt=urn:btih:demo")!,
                        rawValue: "magnet:?xt=urn:btih:demo"
                    ),
                    sourceDescription: "Буфер обмена"
                ),
                connectionEnvironment: .preview(server: .previewLocalHTTP)
            )
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
}
