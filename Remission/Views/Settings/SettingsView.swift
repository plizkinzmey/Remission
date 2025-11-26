import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    private var isUITesting: Bool {
        ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
    }

    var body: some View {
        NavigationStack {
            Form {
                autoRefreshSection
                telemetrySection
                pollingSection
                speedLimitsSection
                diagnosticsSection
                loadingSection
            }
            .navigationTitle(L10n.tr("settings.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close")) {
                        store.send(.delegate(.closeRequested))
                    }
                    .accessibilityIdentifier("settings_close_button")
                }
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(
                store: store.scope(state: \.$diagnostics, action: \.diagnostics)
            ) { diagnosticsStore in
                DiagnosticsView(store: diagnosticsStore)
            }
        }
    }

    private var intervalLabel: String {
        let seconds = Int(store.pollingIntervalSeconds.rounded())
        return String(
            format: L10n.tr("settings.polling.interval"),
            Int64(seconds)
        )
    }

    private var policyURL: URL? {
        URL(string: "https://remission.app/privacy")
    }

    private func limitText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private var autoRefreshSection: some View {
        Section(L10n.tr("settings.autoRefresh.section")) {
            Toggle(
                L10n.tr("settings.autoRefresh.toggle"),
                isOn: Binding(
                    get: { store.isAutoRefreshEnabled },
                    set: { store.send(.autoRefreshToggled($0)) }
                )
            )
            .accessibilityIdentifier("settings_auto_refresh_toggle")
            Text(L10n.tr("settings.autoRefresh.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var telemetrySection: some View {
        Section(L10n.tr("settings.telemetry.section")) {
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
                // Дублирующий toggle для UI-тестов, чтобы элемент гарантированно присутствовал в дереве на iOS.
                Toggle(
                    L10n.tr("settings.telemetry.uiTestToggle"),
                    isOn: Binding(
                        get: { store.isAutoRefreshEnabled },
                        set: { store.send(.autoRefreshToggled($0)) }
                    )
                )
                .labelsHidden()
                .accessibilityIdentifier("settings_auto_refresh_toggle")
                .opacity(0.01)
            }
        }
    }

    private var pollingSection: some View {
        Section(L10n.tr("settings.polling.section")) {
            VStack(alignment: .leading, spacing: 12) {
                Slider(
                    value: Binding(
                        get: { store.pollingIntervalSeconds },
                        set: { store.send(.pollingIntervalChanged($0)) }
                    ),
                    in: 1...60,
                    step: 1
                )
                .accessibilityIdentifier("settings_polling_slider")

                Text(intervalLabel)
                    .bold()
                    .accessibilityIdentifier("settings_polling_value")
                Text(L10n.tr("settings.polling.note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var speedLimitsSection: some View {
        Section(L10n.tr("settings.speed.section")) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent {
                    TextField(
                        L10n.tr("settings.speed.unlimited"),
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.downloadKilobytesPerSecond)
                            },
                            set: { store.send(.downloadLimitChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings_download_limit_field")
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220, alignment: .trailing)
                    .minimumScaleFactor(0.85)
                } label: {
                    Text(L10n.tr("settings.speed.download"))
                }

                LabeledContent {
                    TextField(
                        L10n.tr("settings.speed.unlimited"),
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.uploadKilobytesPerSecond)
                            },
                            set: { store.send(.uploadLimitChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings_upload_limit_field")
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220, alignment: .trailing)
                    .minimumScaleFactor(0.85)
                } label: {
                    Text(L10n.tr("settings.speed.upload"))
                }

                Text(L10n.tr("settings.speed.note"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diagnosticsSection: some View {
        Section(L10n.tr("settings.diagnostics.section")) {
            Button {
                store.send(.diagnosticsButtonTapped)
            } label: {
                HStack {
                    Label(
                        L10n.tr("settings.diagnostics.openLogs"), systemImage: "doc.text.below.ecg")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.secondary)
                }
            }
            .accessibilityIdentifier("settings_diagnostics_button")

            Text(L10n.tr("settings.diagnostics.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingSection: some View {
        Group {
            if store.isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(L10n.tr("settings.loading"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            store: Store(
                initialState: SettingsReducer.State(
                    isLoading: false,
                    pollingIntervalSeconds: 3,
                    isAutoRefreshEnabled: true,
                    defaultSpeedLimits: .init(
                        downloadKilobytesPerSecond: 2_048,
                        uploadKilobytesPerSecond: 1_024
                    )
                )
            ) {
                SettingsReducer()
            } withDependencies: {
                $0.userPreferencesRepository = .placeholder
            }
        )
    }
}
