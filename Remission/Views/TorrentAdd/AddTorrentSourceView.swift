import ComposableArchitecture
import SwiftUI

struct AddTorrentSourceView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("torrentAdd.source.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar(contentPadding: 6) {
                        Spacer(minLength: 0)
                        Button(L10n.tr("common.cancel")) {
                            store.send(.delegate(.closeRequested))
                        }
                        .accessibilityIdentifier("torrent_add_source_close_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                        Button(L10n.tr("torrentAdd.source.continue")) {
                            // Close source picker and show submission form
                            store.send(.closeButtonTapped)
                        }
                        .disabled(continueDisabled)
                        .accessibilityIdentifier("torrent_add_source_continue_button")
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
            #else
                windowContent
                    .navigationTitle(L10n.tr("torrentAdd.source.title"))
            #endif
        }
        #if os(macOS)
            .frame(minWidth: 520, idealWidth: 640, maxWidth: 760)
        #endif
        #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        store.send(.delegate(.closeRequested))
                    }
                    .accessibilityIdentifier("torrent_add_source_close_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("torrentAdd.source.continue")) {
                        store.send(.closeButtonTapped)
                    }
                    .disabled(continueDisabled)
                    .accessibilityIdentifier("torrent_add_source_continue_button")
                }
            }
        #endif
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var continueDisabled: Bool {
        switch store.source {
        case .torrentFile:
            return store.selectedFileName == nil
        case .magnetLink:
            return store.pendingInput == nil
        }
    }

    private var windowContent: some View {
        Group {
            #if os(macOS)
                windowFormContent
            #else
                ScrollView {
                    windowFormContent
                }
            #endif
        }
    }
}

extension AddTorrentSourceView {
    private var windowFormContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionCard(L10n.tr("torrentAdd.source.picker.title"), style: .plain) {
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
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .appInteractivePillSurface()
                            .foregroundStyle(.tint)
                            .accessibilityIdentifier("torrent_add_choose_file_button")

                            if let fileName = store.selectedFileName {
                                Text(fileName)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .magnetLink:
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField(
                                    L10n.tr("torrentAdd.source.magnet.placeholder"),
                                    text: Binding(
                                        get: { store.magnetText },
                                        set: { store.send(.magnetTextChanged($0)) }
                                    )
                                )
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .appInteractivePillSurface()
                                #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                #endif
                                .accessibilityIdentifier("torrent_add_magnet_field")

                                Button {
                                    store.send(.pasteFromClipboardTapped)
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .frame(width: 34, height: 34)
                                        .appInteractivePillSurface()
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("torrent_add_paste_button")
                            }

                            if store.magnetText.isEmpty == false && store.pendingInput == nil {
                                Text(L10n.tr("serverDetail.addTorrent.invalidMagnet.message"))
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(.bottom, -4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface(cornerRadius: 16)
        .padding(.horizontal, 12)
    }
}

#if DEBUG
    #Preview("Add Torrent Source - Magnet") {
        NavigationStack {
            AddTorrentSourceView(
                store: Store(
                    initialState: {
                        var state = AddTorrentReducer.State(
                            connectionEnvironment: .preview(server: .previewLocalHTTP)
                        )
                        state.source = .magnetLink
                        state.magnetText = "magnet:?xt=urn:btih:demo"
                        state.pendingInput = PendingTorrentInput(
                            payload: .magnetLink(
                                url: URL(string: "magnet:?xt=urn:btih:demo")!,
                                rawValue: "magnet:?xt=urn:btih:demo"
                            ),
                            sourceDescription: "Clipboard"
                        )
                        return state
                    }()
                ) {
                    AddTorrentReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }
#endif
