import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Settings View Coverage")
@MainActor
struct SettingsViewCoverageTests {
    @Test
    func settingsViewRendersLoadingAndLoadedStates() {
        let loadingStore = makeSettingsStore(isLoaded: false)
        let loadingView = SettingsView(store: loadingStore)
        _ = loadingView.body

        let loadedStore = makeSettingsStore(isLoaded: true)
        let loadedView = SettingsView(store: loadedStore)
        _ = loadedView.body

        #expect(loadedStore.withState { $0.persistedPreferences != nil })
        #expect(loadingStore.withState { $0.persistedPreferences == nil })
    }

    @Test
    func settingsSectionsRender() {
        let store = makeSettingsStore(isLoaded: true)

        let autoRefresh = SettingsAutoRefreshSection(store: store)
        _ = autoRefresh.body

        let polling = SettingsPollingSection(store: store)
        _ = polling.body

        let speed = SettingsSpeedLimitsSection(store: store)
        _ = speed.body

        let seedRatio = SettingsSeedRatioSection(store: store)
        _ = seedRatio.body

        let telemetry = SettingsTelemetrySection(store: store, isUITesting: true)
        _ = telemetry.body

        let telemetryLive = SettingsTelemetrySection(store: store, isUITesting: false)
        _ = telemetryLive.body
    }
}

@MainActor
private func makeSettingsStore(isLoaded: Bool) -> StoreOf<SettingsReducer> {
    var state = SettingsReducer.State(
        serverID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        serverName: "Test Server",
        isLoading: isLoaded == false
    )
    state.pollingIntervalSeconds = 3
    state.isAutoRefreshEnabled = false
    state.isTelemetryEnabled = true
    state.isSeedRatioLimitEnabled = true
    state.seedRatioLimitValue = 1.5
    state.defaultSpeedLimits = .init(
        downloadKilobytesPerSecond: 2_048,
        uploadKilobytesPerSecond: 1_024
    )

    if isLoaded {
        state.persistedPreferences = UserPreferences.default
    } else {
        state.persistedPreferences = nil
        state.isLoading = false
    }

    return Store(initialState: state) {
        SettingsReducer()
    } withDependencies: {
        $0 = AppDependencies.makeTestDefaults()
    }
}
