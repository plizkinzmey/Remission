import ComposableArchitecture
import SwiftUI

struct AddTorrentOptionsSection: View {
    @Bindable var store: StoreOf<AddTorrentReducer>

    var body: some View {
        Group {
            AppSectionCard(L10n.tr("torrentAdd.section.category"), style: .card) {
                HStack(spacing: 12) {
                    #if os(macOS)
                        Menu {
                            ForEach(TorrentCategory.ordered, id: \.self) { category in
                                Button(category.title) {
                                    store.send(.categoryChanged(category))
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(store.category.title)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(width: 170, height: 34)
                            .contentShape(Rectangle())
                            .appInteractivePillSurface()
                        }
                        .accessibilityIdentifier("torrent_add_category_picker")
                        .buttonStyle(.plain)
                    #else
                        Picker(
                            "",
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
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("torrent_add_category_picker")
                    #endif

                    Spacer(minLength: 0)
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
    }
}
