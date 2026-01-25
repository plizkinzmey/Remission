import Foundation
import Testing

@testable import Remission

@Suite("API Error Tests")
struct APIErrorTests {
    // Проверяет маппинг HTTP-кодов.
    @Test
    func mapHTTPStatusCodeMapsKnownCodes() {
        #expect(APIError.mapHTTPStatusCode(401) == .unauthorized)
        #expect(APIError.mapHTTPStatusCode(409) == .sessionConflict)

        let unknown = APIError.mapHTTPStatusCode(500)
        if case .unknown(let details) = unknown {
            #expect(details.contains("500"))
        } else {
            Issue.record("Ожидали .unknown для 500")
        }
    }

    // Проверяет маппинг строковых ошибок Transmission.
    @Test
    func mapTransmissionErrorCategorizesByKeywords() {
        #expect(
            APIError.mapTransmissionError("RPC version is unsupported")
                == .versionUnsupported(version: "RPC version is unsupported")
        )
        #expect(
            APIError.mapTransmissionError("invalid json payload")
                == .decodingFailed(underlyingError: "invalid json payload")
        )
        #expect(APIError.mapTransmissionError("authentication failed") == .unauthorized)
        #expect(APIError.mapTransmissionError("session id expired") == .sessionConflict)
    }

    // Проверяет маппинг DecodingError через реальную ошибку декодирования.
    @Test
    func mapDecodingErrorProvidesHelpfulContext() throws {
        struct Payload: Decodable {
            let value: Int
        }

        let data = Data("{}".utf8)
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(Payload.self, from: data)
            Issue.record("Ожидали ошибку декодирования")
        } catch let decodingError as DecodingError {
            let mapped = APIError.mapDecodingError(decodingError)
            if case .decodingFailed(let details) = mapped {
                #expect(details.lowercased().contains("value"))
            } else {
                Issue.record("Ожидали .decodingFailed")
            }
        }
    }

    // Проверяет маппинг URLError в сетевые и TLS-ошибки.
    @Test
    func mapURLErrorMapsNetworkAndTlsFailures() {
        #expect(APIError.mapURLError(URLError(.notConnectedToInternet)) == .networkUnavailable)

        let tls = APIError.mapURLError(URLError(.secureConnectionFailed))
        if case .tlsEvaluationFailed = tls {
            #expect(true)
        } else {
            Issue.record("Ожидали .tlsEvaluationFailed")
        }
    }
}
