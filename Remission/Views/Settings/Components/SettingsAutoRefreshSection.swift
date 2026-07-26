import ComposableArchitecture
import SwiftUI

struct SettingsAutoRefreshSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        Section(
            header: Text(L10n.tr("settings.autoRefresh.section")),
            footer: Text(L10n.tr("settings.autoRefresh.note"))
        ) {
            Toggle(
                L10n.tr("settings.autoRefresh.toggle"),
                isOn: Binding(
                    get: { store.isAutoRefreshEnabled },
                    set: { store.send(.autoRefreshToggled($0)) }
                )
            )
            .accessibilityIdentifier("settings_auto_refresh_toggle")
            .tint(Color.accentColor)
        }
    }
}
