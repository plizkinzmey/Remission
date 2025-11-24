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
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
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
        return "\(seconds) сек."
    }

    private var policyURL: URL? {
        URL(string: "https://remission.app/privacy")
    }

    private func limitText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private var autoRefreshSection: some View {
        Section("Автообновление") {
            Toggle(
                "Обновлять список автоматически",
                isOn: Binding(
                    get: { store.isAutoRefreshEnabled },
                    set: { store.send(.autoRefreshToggled($0)) }
                )
            )
            .accessibilityIdentifier("settings_auto_refresh_toggle")
            Text("Отключите, чтобы обновлять торренты вручную.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var telemetrySection: some View {
        Section("Телеметрия") {
            Toggle(
                "Отправлять анонимную телеметрию",
                isOn: Binding(
                    get: { store.isTelemetryEnabled },
                    set: { store.send(.telemetryToggled($0)) }
                )
            )
            .accessibilityIdentifier("settings_telemetry_toggle")

            Text("По умолчанию выключено. Включите, чтобы помочь улучшить Remission.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let policyURL {
                Link("Политика конфиденциальности", destination: policyURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings_telemetry_policy_link")
            }

            if isUITesting {
                // Дублирующий toggle для UI-тестов, чтобы элемент гарантированно присутствовал в дереве на iOS.
                Toggle(
                    "Обновлять список автоматически (UI Test)",
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
        Section("Интервал опроса") {
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
                Text("Укажите, как часто Remission будет опрашивать Transmission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var speedLimitsSection: some View {
        Section("Лимиты скорости (КБ/с)") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent {
                    TextField(
                        "Не ограничивать",
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.downloadKilobytesPerSecond)
                            },
                            set: { store.send(.downloadLimitChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings_download_limit_field")
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                } label: {
                    Text("Скачивание")
                }

                LabeledContent {
                    TextField(
                        "Не ограничивать",
                        text: Binding(
                            get: {
                                limitText(store.defaultSpeedLimits.uploadKilobytesPerSecond)
                            },
                            set: { store.send(.uploadLimitChanged($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings_upload_limit_field")
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                } label: {
                    Text("Отдача")
                }

                Text("Оставьте поле пустым, чтобы не ограничивать скорость.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diagnosticsSection: some View {
        Section("Диагностика") {
            Button {
                store.send(.diagnosticsButtonTapped)
            } label: {
                HStack {
                    Label("Открыть логи", systemImage: "doc.text.below.ecg")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.secondary)
                }
            }
            .accessibilityIdentifier("settings_diagnostics_button")

            Text("Просмотр последних записей логов для диагностики. Данные остаются на устройстве.")
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
                        Text("Загружаем настройки…")
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
