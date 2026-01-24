import ComposableArchitecture
import SwiftUI

struct SettingsSpeedLimitsSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        AppSectionCard(L10n.tr("settings.speed.section")) {
            AppFormField(L10n.tr("settings.speed.download")) {
                #if os(iOS)
                    LeadingCursorTextField(
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.downloadKilobytesPerSecond)
                            },
                            set: { store.send(.downloadLimitChanged($0)) }
                        ),
                        keyboardType: .decimalPad,
                        textAlignment: .right
                    )
                    .accessibilityIdentifier("settings_download_limit_field")
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .appPillSurface()
                #else
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
                    .textFieldStyle(.appFormField)
                    .frame(maxWidth: 160, alignment: .trailing)
                #endif
            }

            Divider()

            AppFormField(L10n.tr("settings.speed.upload")) {
                #if os(iOS)
                    LeadingCursorTextField(
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.uploadKilobytesPerSecond)
                            },
                            set: { store.send(.uploadLimitChanged($0)) }
                        ),
                        keyboardType: .decimalPad,
                        textAlignment: .right
                    )
                    .accessibilityIdentifier("settings_upload_limit_field")
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .appPillSurface()
                #else
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
                    .textFieldStyle(.appFormField)
                    .frame(maxWidth: 160, alignment: .trailing)
                #endif
            }

            Text(L10n.tr("settings.speed.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func limitText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }
}
