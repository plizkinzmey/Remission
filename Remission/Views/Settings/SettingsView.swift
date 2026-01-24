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
                        AppWindowFooterBar(contentPadding: 6) {
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
                    ScrollView {
                        windowContent
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .appDismissKeyboardOnTap()
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
        }
        .appRootChrome()
    }

    @ViewBuilder
    private var windowContent: some View {
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
                SettingsAutoRefreshSection(store: store)
                if isUITesting {
                    SettingsTelemetrySection(store: store, isUITesting: isUITesting)
                }
                SettingsPollingSection(store: store)
                SettingsSpeedLimitsSection(store: store)
                SettingsSeedRatioSection(store: store)
            }
            .padding(12)
            .appCardSurface(cornerRadius: 16)
            .padding(.horizontal, 12)
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
        state.isSeedRatioLimitEnabled = true
        state.seedRatioLimitValue = 1.5
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
