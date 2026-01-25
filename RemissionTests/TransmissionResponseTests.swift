import Foundation
import Testing

@testable import Remission

@Suite("TransmissionResponse")
struct TransmissionResponseTests {
    @Test("isSuccess/isError/errorMessage следуют контракту Transmission RPC")
    func successAndErrorFlagsFollowTransmissionContract() {
        // Transmission RPC считает успехом только точное значение "success".
        // Всё остальное — ошибка, даже если строка «похожа на успех».
        let success = TransmissionResponse(result: "success")
        let error = TransmissionResponse(result: "too many recent requests")

        #expect(success.isSuccess)
        #expect(!success.isError)
        #expect(success.errorMessage == nil)

        #expect(!error.isSuccess)
        #expect(error.isError)
        #expect(error.errorMessage == "too many recent requests")
    }

    @Test("Кодирование и декодирование сохраняют arguments и tag")
    func codableRoundTripPreservesArgumentsAndTag() throws {
        // Этот тест защищает полезные computed-свойства от регрессий в Codable-слое.
        let original = TransmissionResponse(
            result: "success",
            arguments: .object([
                "download-dir": .string("/downloads")
            ]),
            tag: .string("session-1")
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransmissionResponse.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.arguments?.objectValue?["download-dir"]?.stringValue == "/downloads")
    }
}
