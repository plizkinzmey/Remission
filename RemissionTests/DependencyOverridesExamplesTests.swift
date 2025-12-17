import Dependencies
import Testing

@testable import Remission

@MainActor
struct DependencyOverridesExamplesTests {
    @Test
    func transmissionClientOverrideHappyPath() async throws {
        let dependencies: DependencyValues = DependencyValues.testDependenciesWithOverrides {
            $0.transmissionClient = .previewMock(sessionGet: {
                TransmissionResponse(result: "success", arguments: nil, tag: nil)
            })
        }

        let response = try await dependencies.transmissionClient.sessionGet()
        #expect(response.result == "success")
    }

    @Test
    func transmissionClientOverrideErrorPath() async throws {
        let dependencies: DependencyValues = DependencyValues.testDependenciesWithOverrides {
            $0.transmissionClient = .previewMock(sessionGet: { throw APIError.sessionConflict })
        }

        do {
            _ = try await dependencies.transmissionClient.sessionGet()
            #expect(Bool(false), "Ожидалась ошибка APIError.sessionConflict")
        } catch let error as APIError {
            #expect(error == .sessionConflict)
        }
    }

    @Test
    func credentialsRepositoryOverrideReturnsPreviewSample() async throws {
        let dependencies: DependencyValues = DependencyValues.testDependenciesWithOverrides {
            $0.credentialsRepository = .previewMock()
        }

        let credentials = try await dependencies.credentialsRepository.load(key: .preview)
        #expect(credentials == .preview)
    }
}
