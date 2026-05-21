import ComposableArchitecture
import SwiftUI

struct AddTorrentOptionsSection: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Section(header: Text(L10n.tr("torrentAdd.section.category"))) {
            Picker(
                L10n.tr("torrentAdd.section.category"),
                selection: Binding(
                    get: { store.category },
                    set: { store.send(.categoryChanged($0)) }
                )
            ) {
                ForEach(TorrentCategory.ordered, id: \.self) { category in
                    Text(category.title)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("torrent_add_category_picker")

            Toggle(
                L10n.tr("torrentAdd.toggle.startPaused"),
                isOn: Binding(
                    get: { store.startPaused },
                    set: { store.send(.startPausedChanged($0)) }
                )
            )
            .toggleStyle(.switch)
            .accessibilityIdentifier("torrent_add_start_paused_toggle")
        }
    }
}
