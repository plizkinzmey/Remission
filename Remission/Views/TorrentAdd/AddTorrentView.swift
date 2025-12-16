import ComposableArchitecture
import Foundation
import SwiftUI

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        let displayName = store.pendingInput.displayName
        let sourceDescription = store.pendingInput.sourceDescription
        let destinationBinding = Binding<String>(
            get: { store.destinationPath },
            set: { store.send(.destinationPathChanged($0)) }
        )
        let startPausedBinding = Binding<Bool>(
            get: { store.startPaused },
            set: { store.send(.startPausedChanged($0)) }
        )
        let newTagBinding = Binding<String>(
            get: { store.newTag },
            set: { store.send(.newTagChanged($0)) }
        )

        Form {
            Section(L10n.tr("torrentAdd.section.source")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.body)
                        .bold()
                        .accessibilityIdentifier("torrent_add_source_description")

                    if sourceDescription != displayName {
                        Text(sourceDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrent_add_source_name")
                    }
                }
            }

            Section(L10n.tr("torrentAdd.section.destination")) {
                TextField(
                    "",
                    text: destinationBinding,
                    prompt: Text(L10n.tr("torrentAdd.placeholder.destination"))
                )
                .labelsHidden()
                .textContentType(.URL)
                .accessibilityIdentifier("torrent_add_destination_field")
                .accessibilityHint(L10n.tr("torrentAdd.placeholder.destination"))
            }

            Section(L10n.tr("torrentAdd.section.parameters")) {
                Toggle(L10n.tr("torrentAdd.toggle.startPaused"), isOn: startPausedBinding)
                    .accessibilityIdentifier("torrent_add_start_paused_toggle")
            }

            Section(L10n.tr("torrentAdd.section.tags")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("torrentAdd.placeholder.tag"))
                        .font(.subheadline)
                        .accessibilityIdentifier("torrent_add_tag_title")

                    HStack(spacing: 10) {
                        TextField(
                            "",
                            text: newTagBinding,
                            prompt: Text(L10n.tr("torrentAdd.placeholder.tag"))
                        )
                        .labelsHidden()
                        .accessibilityIdentifier("torrent_add_tag_field")

                        Button {
                            store.send(.addTagTapped)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("torrent_add_tag_button")
                        .accessibilityHint(L10n.tr("torrentAdd.placeholder.tag"))
                    }
                    if store.tags.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.tags, id: \.self) { tag in
                                let tagId = sanitizedTagIdentifier(tag)
                                HStack(spacing: 12) {
                                    Text(tag)
                                        .font(.subheadline)
                                        .accessibilityIdentifier("torrent_add_tag_label_\(tagId)")
                                    Button {
                                        store.send(.removeTag(tag))
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("torrent_add_tag_remove_\(tagId)")
                                    .accessibilityLabel(
                                        String(
                                            format: L10n.tr("Remove tag %@"),
                                            locale: Locale.current,
                                            tag
                                        )
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        Text(L10n.tr("torrentAdd.tags.empty"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("torrentAdd.title"))
        .formStyle(.grouped)
        #if os(macOS)
            .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .cancellationAction) {
                Button(L10n.tr("torrentAdd.action.cancel")) {
                    store.send(.closeButtonTapped)
                }
                .accessibilityIdentifier("torrent_add_cancel_button")

                Button(L10n.tr("serverDetail.button.close")) {
                    store.send(.closeButtonTapped)
                }
                .accessibilityIdentifier("torrent_add_close_button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.tr("torrentAdd.action.add")) {
                    store.send(.submitButtonTapped)
                }
                .disabled(
                    store.isSubmitting
                        || store.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                )
                .accessibilityIdentifier("torrent_add_submit_button")
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

extension AddTorrentView {
    fileprivate func sanitizedTagIdentifier(_ tag: String) -> String {
        tag.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }
}

#Preview {
    NavigationStack {
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
                    connectionEnvironment: .preview(server: .previewLocalHTTP),
                    destinationPath: "/downloads",
                    startPaused: true,
                    tags: ["linux", "ubuntu"]
                )
            ) {
                AddTorrentReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
    }
}

/// Простой layout для вывода тегов в несколько строк.
