import ComposableArchitecture
import SwiftUI

struct SettingsSeedRatioSection: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        Section(
            header: Text(L10n.tr("settings.seedRatio.section")),
            footer: Text(L10n.tr("settings.seedRatio.note"))
        ) {
            LabeledContent(L10n.tr("settings.seedRatio.limit")) {
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
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
            }
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
