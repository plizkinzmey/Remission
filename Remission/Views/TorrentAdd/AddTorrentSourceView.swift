import ComposableArchitecture
import SwiftUI

struct AddTorrentSourceView: View {
    @Bindable var store: StoreOf<AddTorrentSourceReducer>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("torrentAdd.source.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar {
                        Spacer(minLength: 0)
                        Button(L10n.tr("torrentAdd.action.cancel")) {
                            store.send(.delegate(.closeRequested))
                        }
                        .accessibilityIdentifier("torrent_add_source_close_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                        Button(L10n.tr("torrentAdd.source.continue")) {
                            store.send(.continueTapped)
                        }
                        .disabled(continueDisabled)
                        .accessibilityIdentifier("torrent_add_source_continue_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .accent))
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
        #endif
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

    private var windowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionCard(L10n.tr("torrentAdd.source.picker.title"), style: .plain) {
                    Picker(
                        L10n.tr("torrentAdd.source.picker.title"),
                        selection: Binding(
                            get: { store.source },
                            set: { store.send(.sourceChanged($0)) }
                        )
                    ) {
                        Text(L10n.tr("torrentAdd.source.option.file"))
                            .tag(AddTorrentSourceReducer.Source.torrentFile)
                        Text(L10n.tr("torrentAdd.source.option.magnet"))
                            .tag(AddTorrentSourceReducer.Source.magnetLink)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    #if os(macOS)
                        .controlSize(.large)
                    #endif
                    .accessibilityIdentifier("torrent_add_source_picker")
                }

                switch store.source {
                case .torrentFile:
                    AppSectionCard("", style: .plain) {
                        Button(L10n.tr("torrentAdd.source.chooseFile")) {
                            store.send(.chooseFileTapped)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .appPillSurface()
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityIdentifier("torrent_add_choose_file_button")
                    }

                case .magnetLink:
                    AppSectionCard("", style: .plain) {
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
                        .appPillSurface()
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #endif
                        .accessibilityIdentifier("torrent_add_magnet_field")
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardSurface(cornerRadius: 16)
            .padding(.horizontal, 12)
        }
    }
}
