import Foundation

@testable import Remission

enum TransmissionFixtureLoader {
    static func loadResponse(_ relativePath: String) throws -> TransmissionResponse {
        let supportDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let testsDirectory = supportDirectory.deletingLastPathComponent()
        let fixtureURL =
            testsDirectory
            .appendingPathComponent("Fixtures/Transmission", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: false)

        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(TransmissionResponse.self, from: data)
    }
}
