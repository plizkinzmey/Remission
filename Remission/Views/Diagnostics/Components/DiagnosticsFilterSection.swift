import ComposableArchitecture
import SwiftUI

struct DiagnosticsFilterSection: View {
    @Bindable var store: StoreOf<DiagnosticsReducer>

    var body: some View {
        AppSectionCard(L10n.tr("diagnostics.level")) {
            fieldRow(label: L10n.tr("diagnostics.level")) {
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
                .tint(AppTheme.accent)
                #if os(macOS)
                    .controlSize(.large)
                #endif
            }

            Divider()

            TextField(
                L10n.tr("diagnostics.search.placeholder"),
                text: $store.query.sending(\.queryChanged)
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .appPillSurface()
            .accessibilityIdentifier("diagnostics_search_field")
        }
    }

    private func fieldRow<Content: View>(
        label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            field()
                .frame(maxWidth: 360, alignment: .trailing)
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
