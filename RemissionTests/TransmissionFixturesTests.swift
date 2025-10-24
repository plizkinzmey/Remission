import Foundation
import Testing

@testable import Remission

@Suite("Transmission Fixtures")
struct TransmissionFixturesTests {
    @Test(
        "session-get success fixture decodes and exposes rpc-version"
    )
    func sessionGetSuccess() throws {
        let response: TransmissionResponse = try TransmissionFixture.response(
            .sessionGetSuccessRPC17)

        #expect(response.isSuccess)
        #expect(response.tag == .int(1))

        let rpcVersion: Int? = response.arguments?
            .objectValue?["rpc-version"]?
            .intValue
        #expect(rpcVersion == 17)
    }

    @Test(
        "torrent-get success fixture contains torrents payload"
    )
    func torrentGetFixture() throws {
        let response: TransmissionResponse = try TransmissionFixture.response(
            .torrentGetSingleActive)
        #expect(response.isSuccess)

        let torrents: [AnyCodable]? = response.arguments?
            .objectValue?["torrents"]?
            .arrayValue
        #expect(torrents?.isEmpty == false)

        let firstTorrentName: String? = torrents?
            .first?
            .objectValue?["name"]?
            .stringValue
        #expect(firstTorrentName == "Ubuntu 24.04 LTS")
    }

    @Test(
        "error fixtures map to APIError cases"
    )
    func errorFixtures() throws {
        let tooManyRequests: TransmissionResponse = try TransmissionFixture.response(
            .rpcErrorTooManyRequests)
        #expect(tooManyRequests.isError)
        #expect(
            APIError.mapTransmissionError(tooManyRequests.result)
                == .unknown(details: tooManyRequests.result)
        )

        let authFailed: TransmissionResponse = try TransmissionFixture.response(
            .rpcErrorAuthFailed)
        #expect(authFailed.isError)
        #expect(APIError.mapTransmissionError(authFailed.result) == .unauthorized)

        let invalidJSON: TransmissionResponse = try TransmissionFixture.response(
            .rpcErrorInvalidJSON)
        #expect(invalidJSON.isError)
        #expect(
            APIError.mapTransmissionError(invalidJSON.result)
                == .decodingFailed(underlyingError: invalidJSON.result)
        )
    }

    @Test(
        "mock response plan helper uses fixture contents"
    )
    func mockResponsePlanFromFixture() throws {
        let successPlan: TransmissionMockResponsePlan = try TransmissionMockResponsePlan.fixture(
            .torrentStartSuccess)
        if case .rpcSuccess(let arguments, let tag) = successPlan {
            #expect(arguments?.objectValue?.isEmpty ?? true)
            #expect(tag == .string("torrent-start"))
        } else {
            Issue.record("Expected rpcSuccess plan")
        }

        let errorPlan: TransmissionMockResponsePlan = try TransmissionMockResponsePlan.fixture(
            .rpcErrorTooManyRequests)
        if case .rpcError(let result, let statusCode, _) = errorPlan {
            #expect(result == "too many recent requests")
            #expect(statusCode == 200)
        } else {
            Issue.record("Expected rpcError plan")
        }
    }
}
