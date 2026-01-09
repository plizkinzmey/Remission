import ComposableArchitecture
import Foundation
import SwiftUI

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Group {
            #if os(macOS)
                VStack(spacing: 12) {
                    AppWindowHeader(L10n.tr("torrentAdd.title"))
                    windowContent
                }
                .safeAreaInset(edge: .bottom) {
                    AppWindowFooterBar {
                        Spacer(minLength: 0)
                        Button(L10n.tr("torrentAdd.action.cancel")) {
                            store.send(.closeButtonTapped)
                        }
                        .accessibilityIdentifier("torrent_add_cancel_button")
                        .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                        Button(L10n.tr("torrentAdd.action.add")) {
                            store.send(.submitButtonTapped)
                        }
                        .disabled(
                            store.isSubmitting
                                || store.destinationPath.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty
                        )
                        .accessibilityIdentifier("torrent_add_submit_button")
                        .buttonStyle(AppPrimaryButtonStyle())
                    }
                }
            #else
                windowContent
                    .navigationTitle(L10n.tr("torrentAdd.title"))
            #endif
        }
        #if os(macOS)
            .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
        #endif
        #if !os(macOS)
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
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

extension AddTorrentView {
    fileprivate func sanitizedTagIdentifier(_ tag: String) -> String {
        tag.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }
}

extension AddTorrentView {
    fileprivate var windowContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppSectionCard(L10n.tr("torrentAdd.section.source"), style: .card) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.pendingInput.displayName)
                            .font(.body.weight(.semibold))
                            .accessibilityIdentifier("torrent_add_source_description")

                        if store.pendingInput.sourceDescription != store.pendingInput.displayName {
                            Text(store.pendingInput.sourceDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("torrent_add_source_name")
                        }
                    }
                }

                AppSectionCard(L10n.tr("torrentAdd.section.destination"), style: .card) {
                    TextField(
                        "",
                        text: Binding(
                            get: { store.destinationPath },
                            set: { store.send(.destinationPathChanged($0)) }
                        ),
                        prompt: Text(L10n.tr("torrentAdd.placeholder.destination"))
                    )
                    .labelsHidden()
                    .textContentType(.URL)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .appPillSurface()
                    .accessibilityIdentifier("torrent_add_destination_field")
                    .accessibilityHint(L10n.tr("torrentAdd.placeholder.destination"))
                }

                AppSectionCard(L10n.tr("torrentAdd.section.tags"), style: .card) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            TextField(
                                "",
                                text: Binding(
                                    get: { store.newTag },
                                    set: { store.send(.newTagChanged($0)) }
                                ),
                                prompt: Text(L10n.tr("torrentAdd.placeholder.tag"))
                            )
                            .labelsHidden()
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .appPillSurface()
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
                                    let tagLabelId = "torrent_add_tag_label_\(tagId)"
                                    HStack(spacing: 12) {
                                        Text(tag)
                                            .font(.subheadline)
                                            .accessibilityIdentifier(tagLabelId)
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

                AppSectionCard("", style: .plain) {
                    HStack(spacing: 12) {
                        Text(L10n.tr("torrentAdd.toggle.startPaused"))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.startPaused },
                                set: { store.send(.startPausedChanged($0)) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("torrent_add_start_paused_toggle")
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
