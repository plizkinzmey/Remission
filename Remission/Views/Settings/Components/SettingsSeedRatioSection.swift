import ComposableArchitecture
import SwiftUI

struct SettingsSeedRatioSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        AppSectionCard(L10n.tr("settings.seedRatio.section")) {
            AppFormField(L10n.tr("settings.seedRatio.limit")) {
                #if os(iOS)
                    LeadingCursorTextField(
                        text: Binding(
                            get: {
                                ratioText(
                                    isEnabled: store.isSeedRatioLimitEnabled,
                                    value: store.seedRatioLimitValue
                                )
                            },
                            set: { store.send(.seedRatioLimitChanged($0)) }
                        ),
                        keyboardType: .decimalPad,
                        textAlignment: .right
                    )
                    .accessibilityIdentifier("settings_seed_ratio_field")
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .appInteractivePillSurface()
                #else
                    TextField(
                        "",
                        text: Binding(
                            get: {
                                ratioText(
                                    isEnabled: store.isSeedRatioLimitEnabled,
                                    value: store.seedRatioLimitValue
                                )
                            },
                            set: { store.send(.seedRatioLimitChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings_seed_ratio_field")
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.appFormField)
                    .frame(maxWidth: 160, alignment: .trailing)
                #endif
            }

            Text(L10n.tr("settings.seedRatio.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func ratioText(isEnabled: Bool, value: Double) -> String {
        guard isEnabled else { return "0" }
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = Locale.current.decimalSeparator
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
