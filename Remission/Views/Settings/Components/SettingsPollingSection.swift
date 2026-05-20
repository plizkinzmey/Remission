import ComposableArchitecture
import SwiftUI

struct SettingsPollingSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        Section(
            header: Text(L10n.tr("settings.polling.section")),
            footer: Text(L10n.tr("settings.polling.note"))
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Slider(
                    value: Binding(
                        get: { store.pollingIntervalSeconds },
                        set: { store.send(.pollingIntervalChanged($0)) }
                    ),
                    in: 1...60,
                    step: 1
                )
                .accessibilityIdentifier("settings_polling_slider")
                .tint(Color.accentColor)

                Text(intervalLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("settings_polling_value")
            }
            .padding(.vertical, 4)
        }
        .disabled(store.isAutoRefreshEnabled == false)
    }

    private var intervalLabel: String {
        let seconds = Int(store.pollingIntervalSeconds.rounded())
        return String(
            format: L10n.tr("settings.polling.interval"),
            Int64(seconds)
        )
    }
}
