import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class AddTorrentFeatureTests: XCTestCase {

    func testTask_LoadsDefaults() async {
        let serverID = UUID()
        let defaultDir = "/downloads/custom"
        let prefs = UserPreferences.default

        var sessionRepo = SessionRepository.placeholder
        sessionRepo.fetchStateClosure = { @Sendable in
            // Delay mock response so preferences arrive first in this merged effect.
            try? await Task.sleep(nanoseconds: 50_000_000)
            var state = SessionState.previewActive
            state.downloadDirectory = defaultDir
            return state
        }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            sessionRepository: sessionRepo
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                connectionEnvironment: environment, serverID: serverID)
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0.userPreferencesRepository.loadClosure = { @Sendable _ in prefs }
        }

        await store.send(AddTorrentReducer.Action.task)

        // Actions now arrive in a deterministic order due to the controlled mock delay
        await store.receive(AddTorrentReducer.Action.preferencesResponse(.success(prefs)))
        await store.receive(
            AddTorrentReducer.Action.defaultDownloadDirectoryResponse(.success(defaultDir))
        ) {
            $0.serverDownloadDirectory = defaultDir
            $0.destinationPath = defaultDir
        }
    }

    func testSourceChanged() async {
        let store = TestStore(initialState: AddTorrentReducer.State()) {
            AddTorrentReducer()
        }

        await store.send(AddTorrentReducer.Action.sourceChanged(.magnetLink)) {
            $0.source = .magnetLink
            $0.pendingInput = nil
        }

        await store.send(AddTorrentReducer.Action.magnetTextChanged("magnet:?xt=urn:btih:abc")) {
            $0.magnetText = "magnet:?xt=urn:btih:abc"
            $0.pendingInput = PendingTorrentInput(
                payload: .magnetLink(
                    url: URL(string: "magnet:?xt=urn:btih:abc")!,
                    rawValue: "magnet:?xt=urn:btih:abc"),
                sourceDescription: "Magnet"
            )
        }
    }

    func testSubmit_Success() async {
        let input = PendingTorrentInput(
            payload: .magnetLink(
                url: URL(string: "magnet:?xt=urn:btih:abc")!, rawValue: "magnet:?xt=urn:btih:abc"),
            sourceDescription: "Magnet"
        )
        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: Torrent.Identifier(rawValue: 1),
            name: "Test Torrent",
            hashString: "abc"
        )

        var torrentRepo = TorrentRepository.testValue
        torrentRepo.addClosure = { @Sendable _, _, _, _ in addResult }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            torrentRepository: torrentRepo
        )

        let store = TestStore(
            initialState: AddTorrentReducer.State(
                pendingInput: input, connectionEnvironment: environment)
        ) {
            AddTorrentReducer()
        } withDependencies: {
            $0.userPreferencesRepository.updateRecentDownloadDirectoriesClosure =
                { @Sendable _, _ in .default }
        }

        // Set destination path to avoid validation error
        await store.send(AddTorrentReducer.Action.destinationPathChanged("/downloads")) {
            $0.destinationPath = "/downloads"
        }

        await store.send(AddTorrentReducer.Action.submitButtonTapped) {
            $0.isSubmitting = true
        }

        await store.receive(
            AddTorrentReducer.Action.submitResponse(
                .success(AddTorrentReducer.SubmitResult(addResult: addResult)))
        ) {
            $0.isSubmitting = false
            $0.closeOnAlertDismiss = true
            $0.alert = AlertFactory.torrentAdded(
                name: addResult.name,
                isDuplicate: false,
                action: AddTorrentReducer.AlertAction.dismiss
            )
        }
    }
}
