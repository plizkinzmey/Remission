import ComposableArchitecture
import SwiftUI

struct AddTorrentDestinationSection: View {
    @Bindable var store: StoreOf<AddTorrentReducer>
    @State private var isCustomPathEditorPresented: Bool = false
    @State private var customPathDraft: String = ""
    private let destinationFieldHeight: CGFloat = 32

    var body: some View {
        AppSectionCard(L10n.tr("torrentAdd.section.destination"), style: .card) {
            destinationMenu
        }
        .sheet(isPresented: $isCustomPathEditorPresented) {
            customPathEditor
        }
    }

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
