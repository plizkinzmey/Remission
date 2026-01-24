import ComposableArchitecture
import SwiftUI

struct SettingsPollingSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        AppSectionCard(L10n.tr("settings.polling.section")) {
            Slider(
                value: Binding(
                    get: { store.pollingIntervalSeconds },
                    set: { store.send(.pollingIntervalChanged($0)) }
                ),
                in: 1...60,
                step: 1
            )
            .accessibilityIdentifier("settings_polling_slider")
            .tint(AppTheme.accent)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appPillSurface()

            Text(intervalLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("settings_polling_value")
            Text(L10n.tr("settings.polling.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .disabled(store.isAutoRefreshEnabled == false)
        .opacity(store.isAutoRefreshEnabled ? 1 : 0.6)
    }

    private var intervalLabel: String {
        let seconds = Int(store.pollingIntervalSeconds.rounded())
        return String(
            format: L10n.tr("settings.polling.interval"),
            Int64(seconds)
        )
    }
}
