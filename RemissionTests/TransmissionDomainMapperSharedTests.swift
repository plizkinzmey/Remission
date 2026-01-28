import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper Shared")
struct TransmissionDomainMapperSharedTests {
    @Test("arguments(from:) возвращает словарь при success и бросает rpcError при ошибке")
    func argumentsValidatesResultAndReturnsDictionary() throws {
        // Этот тест фиксирует центральный контракт: любые не-success ответы
        // должны прерывать маппинг на самом раннем этапе.
        let mapper = TransmissionDomainMapper()

        let successResponse = TransmissionResponse(
            result: "success",
            arguments: .object(["value": .int(1)])
        )

        let arguments = try mapper.arguments(from: successResponse, context: "session-get")
        #expect(arguments["value"] == .int(1))

        let errorResponse = TransmissionResponse(result: "permission denied")

        #expect(throws: DomainMappingError.self) {
            try mapper.arguments(from: errorResponse, context: "session-get")
        }
    }

    @Test("requireArguments бросает missingArguments и invalidType для некорректных payload")
    func requireArgumentsRejectsMissingAndNonObjectArguments() {
        // Мы защищаемся от двух типичных проблем API:
        // 1) arguments отсутствует
        // 2) arguments есть, но не объект
        let mapper = TransmissionDomainMapper()

        let missingArguments = TransmissionResponse(result: "success", arguments: nil)
        #expect(throws: DomainMappingError.missingArguments(context: "torrent-get")) {
            try mapper.requireArguments(from: missingArguments, context: "torrent-get")
        }

        let nonObjectArguments = TransmissionResponse(result: "success", arguments: .array([]))
        #expect(
            throws: DomainMappingError.invalidType(
                field: "arguments",
                expected: "object",
                context: "torrent-get"
            )
        ) {
            try mapper.requireArguments(from: nonObjectArguments, context: "torrent-get")
        }
    }

    @Test("intValue/doubleValue делают безопасные приведения между int и double")
    func numericAccessorsCoerceBetweenIntAndDouble() {
        // В реальных ответах Transmission встречаются и int, и double.
        // Маппер должен одинаково надёжно их читать.
        let mapper = TransmissionDomainMapper()
        let dict: [String: AnyCodable] = [
            "int": .int(7),
            "double": .double(3.5)
        ]

        #expect(mapper.intValue("int", in: dict) == 7)
        #expect(mapper.intValue("double", in: dict) == 3)
        #expect(mapper.doubleValue("int", in: dict) == 7.0)
        #expect(mapper.doubleValue("double", in: dict) == 3.5)
    }

    @Test("decode выполняет round-trip через AnyCodable и валится при nil arguments")
    func decodeSupportsRoundTripAndRejectsNil() throws {
        // Этот тест защищает вспомогательный декодер, на котором построены mapTorrent*.
        let mapper = TransmissionDomainMapper()

        struct Payload: Decodable, Equatable {
            var value: Int
        }

        let decoded = try mapper.decode(
            Payload.self,
            from: .object(["value": .int(42)])
        )
        #expect(decoded == Payload(value: 42))

        #expect(throws: DomainMappingError.missingArguments(context: "Payload")) {
            try mapper.decode(Payload.self, from: nil)
        }
    }
}
