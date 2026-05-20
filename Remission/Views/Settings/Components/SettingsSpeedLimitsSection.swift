import ComposableArchitecture
import SwiftUI

struct SettingsSpeedLimitsSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        Section(
            header: Text(L10n.tr("settings.speed.section")),
            footer: Text(L10n.tr("settings.speed.note"))
        ) {
            LabeledContent(L10n.tr("settings.speed.download")) {
                TextField(
                    "",
                    text: Binding(
                        get: {
                            limitText(store.defaultSpeedLimits.downloadKilobytesPerSecond)
                        },
                        set: { store.send(.downloadLimitChanged($0)) }
                    )
                )
                .accessibilityIdentifier("settings_download_limit_field")
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
            }

            LabeledContent(L10n.tr("settings.speed.upload")) {
                TextField(
                    "",
                    text: Binding(
                        get: {
                            limitText(store.defaultSpeedLimits.uploadKilobytesPerSecond)
                        },
                        set: { store.send(.uploadLimitChanged($0)) }
                    )
                )
                .accessibilityIdentifier("settings_upload_limit_field")
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
            }
        }
    }

    private func limitText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }
}
