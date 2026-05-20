import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentSourceSection: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Section(header: Text(L10n.tr("torrentAdd.section.source"))) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(
                    L10n.tr("torrentAdd.source.picker.title"),
                    selection: Binding(
                        get: { store.source },
                        set: { store.send(.sourceChanged($0)) }
                    )
                ) {
                    Text(L10n.tr("torrentAdd.source.option.file"))
                        .tag(AddTorrentReducer.Source.torrentFile)
                    Text(L10n.tr("torrentAdd.source.option.magnet"))
                        .tag(AddTorrentReducer.Source.magnetLink)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                #if os(macOS)
                    .controlSize(.large)
                #endif
                .accessibilityIdentifier("torrent_add_source_picker")

                switch store.source {
                case .torrentFile:
                    HStack(alignment: .center, spacing: 12) {
                        Button(L10n.tr("torrentAdd.source.chooseFile")) {
                            store.send(.chooseFileTapped)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("torrent_add_choose_file_button")

                        if let fileName = store.selectedFileName {
                            Text(fileName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .magnetLink:
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
                }
            }
            .padding(.vertical, 4)
        }
    }
}

let torrentContentTypes: [UTType] = {
    if let type = UTType(filenameExtension: "torrent") {
        return [type]
    }
    return [.data]
}()
