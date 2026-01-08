import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    private var isUITesting: Bool {
        ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                    VStack(spacing: 12) {
                        AppWindowHeader(L10n.tr("settings.title"))
                        windowContent
                    }
                    .safeAreaInset(edge: .bottom) {
                        AppWindowFooterBar {
                            Spacer(minLength: 0)
                            Button(L10n.tr("common.cancel")) {
                                store.send(.cancelButtonTapped)
                            }
                            .accessibilityIdentifier("settings_cancel_button")
                            .buttonStyle(AppFooterButtonStyle(variant: .neutral))
                            Button(L10n.tr("common.save")) {
                                store.send(.saveButtonTapped)
                            }
                            .accessibilityIdentifier("settings_save_button")
                            .buttonStyle(AppPrimaryButtonStyle())
                            .disabled(isSaveDisabled)
                        }
                    }
                    .frame(minWidth: 480, idealWidth: 640, maxWidth: 760)
                #else
                    windowContent
                        .navigationTitle(L10n.tr("settings.title"))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.tr("common.cancel")) {
                                    store.send(.cancelButtonTapped)
                                }
                                .accessibilityIdentifier("settings_cancel_button")
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.tr("common.save")) {
                                    store.send(.saveButtonTapped)
                                }
                                .accessibilityIdentifier("settings_save_button")
                                .disabled(isSaveDisabled)
                            }
                        }
                #endif
            }
            .task { await store.send(.task).finish() }
            .alert($store.scope(state: \.alert, action: \.alert))
            .sheet(
                store: store.scope(state: \.$diagnostics, action: \.diagnostics)
            ) { diagnosticsStore in
                DiagnosticsView(store: diagnosticsStore)
                    .appRootChrome()
            }
        }
        .appRootChrome()
    }

    @ViewBuilder
    private var windowContent: some View {
        // Render the Form only when we actually have persisted preferences available.
        // This avoids rendering a default/placeholder UI and then reflowing when
        // real values arrive. Until then show a small loading placeholder.
        if store.persistedPreferences == nil {
            VStack(spacing: 12) {
                if store.isLoading {
                    ProgressView {
                        Text(L10n.tr("settings.loading"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .controlSize(.large)
                    .padding(.vertical, 32)
                } else {
                    // Not loading and we have no persisted preferences — probably
                    // an error occurred. Let the alert show (reducer sets it). As
                    // a fallback show a small message and a retry action.
                    VStack(spacing: 8) {
                        Text(L10n.tr("settings.loading"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Button(L10n.tr("settings.retry")) {
                            store.send(.task)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.vertical, 40)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                autoRefreshSection
                // Telemetry is hidden in production for now — keep it visible for
                // UI tests only so automation and existing tests continue to run.
                if isUITesting {
                    telemetrySection
                }
                pollingSection
                speedLimitsSection
                diagnosticsSection
            }
            .padding(12)
            .appCardSurface(cornerRadius: 16)
            .padding(.horizontal, 12)
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
        AppSectionCard(L10n.tr("settings.autoRefresh.section")) {
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

    private var pollingSection: some View {
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

            Text(intervalLabel)
                .bold()
                .accessibilityIdentifier("settings_polling_value")
            Text(L10n.tr("settings.polling.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .disabled(store.isAutoRefreshEnabled == false)
        .opacity(store.isAutoRefreshEnabled ? 1 : 0.6)
    }

    private var speedLimitsSection: some View {
        AppSectionCard(L10n.tr("settings.speed.section")) {
            // Use explicit label+control layout to avoid overlap and giant gaps.
            LabeledContent {
                HStack(spacing: 8) {
                    Spacer(minLength: 4)
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
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(minWidth: 72, maxWidth: 160, alignment: .trailing)
                    .appPillSurface()
                    .layoutPriority(1)
                }
            } label: {
                Text(L10n.tr("settings.speed.download"))
                    .accessibilityIdentifier("settings_download_limit_label")
            }

            LabeledContent {
                HStack(spacing: 8) {
                    Spacer(minLength: 4)
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
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(minWidth: 72, maxWidth: 160, alignment: .trailing)
                    .appPillSurface()
                    .layoutPriority(1)
                }
            } label: {
                Text(L10n.tr("settings.speed.upload"))
                    .accessibilityIdentifier("settings_upload_limit_label")
            }

            Text(L10n.tr("settings.speed.note"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        AppSectionCard(L10n.tr("settings.diagnostics.section")) {
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

    private var isSaveDisabled: Bool {
        store.isLoading || store.isSaving || store.hasPendingChanges == false
    }
}

#Preview {
    let previewState: SettingsReducer.State = {
        var state = SettingsReducer.State(
            serverID: UUID(),
            serverName: "Preview Server",
            isLoading: false
        )
        state.pollingIntervalSeconds = 3
        state.isAutoRefreshEnabled = true
        state.isTelemetryEnabled = false
        state.persistedPreferences = UserPreferences.default
        state.defaultSpeedLimits = .init(
            downloadKilobytesPerSecond: 2_048,
            uploadKilobytesPerSecond: 1_024
        )
        return state
    }()

    return NavigationStack {
        SettingsView(
            store: Store(initialState: previewState) {
                SettingsReducer()
            } withDependencies: {
                $0.userPreferencesRepository = .placeholder
            }
        )
    }
}
