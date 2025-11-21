import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Лимиты скорости (КБ/с)") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent {
                            TextField(
                                "Не ограничивать",
                                text: Binding(
                                    get: {
                                        limitText(
                                            store.defaultSpeedLimits.downloadKilobytesPerSecond)
                                    },
                                    set: { store.send(.downloadLimitChanged($0)) }
                                )
                            )
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
            .navigationTitle("Настройки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        store.send(.delegate(.closeRequested))
                    }
                }
            }
            .task { await store.send(.task).finish() }
            .onDisappear {
                store.send(.teardown)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }

    private var intervalLabel: String {
        let seconds = Int(store.pollingIntervalSeconds.rounded())
        return "\(seconds) сек."
    }

    private func limitText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            store: Store(
                initialState: SettingsReducer.State()
            ) {
                SettingsReducer()
            } withDependencies: {
                $0.userPreferencesRepository = .placeholder
            }
        )
    }
}
