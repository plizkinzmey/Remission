import ComposableArchitecture
import SwiftUI

struct AddTorrentSourceView: View {
    @Bindable var store: StoreOf<AddTorrentSourceReducer>

    var body: some View {
        Form {
            Section {
                Picker(
                    L10n.tr("torrentAdd.source.picker.title"),
                    selection: Binding(
                        get: { store.source },
                        set: { store.send(.sourceChanged($0)) }
                    )
                ) {
                    Text(L10n.tr("torrentAdd.source.option.file"))
                        .tag(AddTorrentSourceReducer.State.Source.torrentFile)
                    Text(L10n.tr("torrentAdd.source.option.magnet"))
                        .tag(AddTorrentSourceReducer.State.Source.magnetLink)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("torrent_add_source_picker")
            }

            switch store.source {
            case .torrentFile:
                Section {
                    Button(L10n.tr("torrentAdd.source.chooseFile")) {
                        store.send(.chooseFileTapped)
                    }
                    .accessibilityIdentifier("torrent_add_choose_file_button")
                } footer: {
                    Text(L10n.tr("torrentAdd.source.chooseFile.hint"))
                }

            case .magnetLink:
                Section {
                    TextField(
                        L10n.tr("torrentAdd.source.magnet.placeholder"),
                        text: Binding(
                            get: { store.magnetText },
                            set: { store.send(.magnetTextChanged($0)) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("torrent_add_magnet_field")

                    Button(L10n.tr("torrentAdd.source.paste")) {
                        store.send(.pasteFromClipboardTapped)
                    }
                    .accessibilityIdentifier("torrent_add_paste_magnet_button")
                } footer: {
                    Text(L10n.tr("torrentAdd.source.magnet.hint"))
                }
            }
        }
        .navigationTitle(L10n.tr("torrentAdd.source.title"))
        .formStyle(.grouped)
        #if os(macOS)
            .frame(minWidth: 520, idealWidth: 640, maxWidth: 760)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr("torrentAdd.action.cancel")) {
                    store.send(.delegate(.closeRequested))
                }
                .accessibilityIdentifier("torrent_add_source_close_button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.tr("torrentAdd.source.continue")) {
                    store.send(.continueTapped)
                }
                .disabled(continueDisabled)
                .accessibilityIdentifier("torrent_add_source_continue_button")
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var continueDisabled: Bool {
        switch store.source {
        case .torrentFile:
            return true
        case .magnetLink:
            return store.magnetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
