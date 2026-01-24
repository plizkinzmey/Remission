import ComposableArchitecture
import SwiftUI

struct SettingsAutoRefreshSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        AppSectionCard(L10n.tr("settings.autoRefresh.section")) {
            AppFormField(L10n.tr("settings.autoRefresh.toggle")) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.isAutoRefreshEnabled },
                        set: { store.send(.autoRefreshToggled($0)) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings_auto_refresh_toggle")
                .tint(AppTheme.accent)
            }
            Text(L10n.tr("settings.autoRefresh.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
