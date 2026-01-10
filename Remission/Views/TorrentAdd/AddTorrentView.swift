import ComposableArchitecture
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Bindable var store: StoreOf<AddTorrentReducer>
    @State private var isCustomPathEditorPresented: Bool = false
    @State private var customPathDraft: String = ""
    private let destinationFieldHeight: CGFloat = 32

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
                                || store.pendingInput == nil
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
                            || store.pendingInput == nil
                            || store.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                    )
                    .accessibilityIdentifier("torrent_add_submit_button")
                }
            }
        #endif
        .task { await store.send(.task).finish() }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(isPresented: $isCustomPathEditorPresented) {
            customPathEditor
        }
        .fileImporter(
            isPresented: fileImporterBinding,
            allowedContentTypes: torrentContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
    }
}

extension AddTorrentView {
    fileprivate func sanitizedTagIdentifier(_ tag: String) -> String {
        tag.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }
}

extension AddTorrentView {
    private var fileImporterBinding: Binding<Bool> {
        Binding(
            get: { store.isFileImporterPresented },
            set: { store.send(.fileImporterPresented($0)) }
        )
    }

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            store.send(.fileImportResult(.success(url)))
        case .failure(let error):
            store.send(.fileImportResult(.failure(error.localizedDescription)))
        }
    }

    fileprivate var windowContent: some View {
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

extension AddTorrentView {
    private var windowFormContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionCard(L10n.tr("torrentAdd.section.source"), style: .card) {
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
                            .appPillSurface()
                            .foregroundStyle(AppTheme.accent)
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

            AppSectionCard(L10n.tr("torrentAdd.section.destination"), style: .card) {
                destinationMenu
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

extension AddTorrentView {
    private var defaultDestination: String {
        store.serverDownloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var destinationSuggestions: [String] {
        let defaultPath = defaultDestination
        let recent = store.recentDownloadDirectories.filter { $0 != defaultPath }
        var combined: [String] = []
        if defaultPath.isEmpty == false {
            combined.append(defaultPath)
        }
        for value in recent where combined.contains(value) == false {
            combined.append(value)
        }
        return combined
    }
}

extension AddTorrentView {
    private var destinationMenu: some View {
        let customPaths = destinationSuggestions.filter { $0 != defaultDestination }
        return Menu {
            Button(L10n.tr("torrentAdd.destination.custom")) {
                customPathDraft = store.destinationPath
                isCustomPathEditorPresented = true
            }

            if destinationSuggestions.isEmpty == false {
                Divider()

                ForEach(destinationSuggestions, id: \.self) { path in
                    Button(path) {
                        store.send(.destinationSuggestionSelected(path))
                    }
                }
            }

            if customPaths.isEmpty == false {
                Divider()

                Menu(L10n.tr("torrentAdd.destination.remove")) {
                    ForEach(customPaths, id: \.self) { path in
                        Button(role: .destructive) {
                            store.send(.destinationSuggestionDeleted(path))
                        } label: {
                            Text(path)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(
                    store.destinationPath.isEmpty
                        ? L10n.tr("torrentAdd.placeholder.destination")
                        : store.destinationPath
                )
                .lineLimit(1)
                .foregroundStyle(
                    store.destinationPath.isEmpty ? .secondary : .primary
                )
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: destinationFieldHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .appPillSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("torrentAdd.destination.suggestions"))
        .accessibilityIdentifier("torrent_add_destination_field")
    }

    private var customPathEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("torrentAdd.destination.customTitle"))
                .font(.headline)
            TextField(
                L10n.tr("torrentAdd.placeholder.destination"),
                text: $customPathDraft
            )
            .textFieldStyle(.roundedBorder)
            .textContentType(.URL)
            HStack {
                Spacer(minLength: 0)
                Button(L10n.tr("common.cancel")) {
                    isCustomPathEditorPresented = false
                }
                Button(L10n.tr("common.save")) {
                    store.send(.destinationPathChanged(customPathDraft))
                    isCustomPathEditorPresented = false
                }
                .disabled(customPathDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}

#Preview {
    NavigationStack {
        AddTorrentView(
            store: Store(
                initialState: {
                    var state = AddTorrentReducer.State(
                        connectionEnvironment: .preview(server: .previewLocalHTTP)
                    )
                    state.destinationPath = "/downloads"
                    state.startPaused = true
                    state.tags = ["linux", "ubuntu"]
                    state.source = .magnetLink
                    state.magnetText = "magnet:?xt=urn:btih:demo"
                    state.pendingInput = PendingTorrentInput(
                        payload: .magnetLink(
                            url: URL(string: "magnet:?xt=urn:btih:demo")!,
                            rawValue: "magnet:?xt=urn:btih:demo"
                        ),
                        sourceDescription: "Буфер обмена"
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

private let torrentContentTypes: [UTType] = {
    if let type = UTType(filenameExtension: "torrent") {
        return [type]
    }
    return [.data]
}()

/// Простой layout для вывода тегов в несколько строк.
