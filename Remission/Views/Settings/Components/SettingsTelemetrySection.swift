import ComposableArchitecture
import SwiftUI

struct SettingsTelemetrySection: View {
    @Bindable var store: StoreOf<SettingsReducer>
    let isUITesting: Bool

    var body: some View {
        AppSectionCard(L10n.tr("settings.telemetry.section")) {
            Toggle(
                L10n.tr("settings.telemetry.toggle"),
                isOn: Binding(
                    get: { store.isTelemetryEnabled },
                    set: { store.send(.telemetryToggled($0)) }
                )
            )
            .accessibilityIdentifier("settings_telemetry_toggle")

            Text(L10n.tr("settings.telemetry.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let policyURL {
                Link(L10n.tr("settings.telemetry.policy"), destination: policyURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings_telemetry_policy_link")
            }

            if isUITesting {
                // UITests stub — provide a predictable element for automation without
                // reusing production accessibility identifiers or bindings.
                Toggle(
                    L10n.tr("settings.telemetry.uiTestToggle"),
                    isOn: Binding(
                        get: { store.isTelemetryEnabled },
                        set: { store.send(.telemetryToggled($0)) }
                    )
                )
                .labelsHidden()
                .accessibilityIdentifier("settings_telemetry_test_stub")
                .opacity(0.01)
            }
        }
    }

    private var policyURL: URL? {
        URL(string: "https://remission.app/privacy")
    }
}
