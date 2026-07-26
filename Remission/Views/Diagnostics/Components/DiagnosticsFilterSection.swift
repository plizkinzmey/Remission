import ComposableArchitecture
import SwiftUI

struct DiagnosticsFilterSection: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                LabeledContent(L10n.tr("diagnostics.level")) {
                    Picker(
                        "",
                        selection: $store.selectedLevel.sending(\.levelSelected)
                    ) {
                        Text(L10n.tr("diagnostics.level.all")).tag(AppLogLevel?.none)
                        ForEach(diagnosticsLevelOptions, id: \.self) { level in
                            Text(diagnosticsLevelLabel(level)).tag(AppLogLevel?.some(level))
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("diagnostics_level_picker")
                    .tint(Color.accentColor)
                    #if os(macOS)
                        .controlSize(.large)
                    #endif
                    .frame(maxWidth: 360)
                }

                Divider()

                LabeledContent(L10n.tr("diagnostics.mode")) {
                    Picker(
                        "",
                        selection: $store.viewMode.sending(\.viewModeChanged)
                    ) {
                        Text(L10n.tr("diagnostics.mode.list")).tag(DiagnosticsViewMode.list)
                        Text(L10n.tr("diagnostics.mode.json")).tag(DiagnosticsViewMode.text)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("diagnostics_mode_picker")
                    .tint(Color.accentColor)
                    #if os(macOS)
                        .controlSize(.large)
                    #endif
                    .frame(maxWidth: 360)
                }

                Divider()

                LabeledContent(L10n.tr("diagnostics.live")) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { store.isLive },
                            set: { _ in store.send(.toggleLive) }
                        )
                    )
                    .toggleStyle(.switch)
                    .tint(Color.accentColor)
                    .labelsHidden()
                    .accessibilityIdentifier("diagnostics_live_toggle")
                }

                Divider()

                TextField(
                    L10n.tr("diagnostics.search.placeholder"),
                    text: $store.query.sending(\.queryChanged)
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("diagnostics_search_field")
            }
            .padding(4)
        }
    }

    private let diagnosticsLevelOptions: [AppLogLevel] = [.error, .warning, .info, .debug]

    private func diagnosticsLevelLabel(_ level: AppLogLevel) -> String {
        switch level {
        case .debug: return L10n.tr("diagnostics.level.debug")
        case .info: return L10n.tr("diagnostics.level.info")
        case .warning: return L10n.tr("diagnostics.level.warn")
        case .error: return L10n.tr("diagnostics.level.error")
        }
    }
}
