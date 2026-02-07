import Foundation
import Testing

@testable import Remission

@Suite("Transmission Domain Mapper Core")
struct TransmissionDomainMapperCoreTests {
    @Test
    func domainMappingErrorDescriptionsAreStable() throws {
        let cases: [(DomainMappingError, String)] = [
            (
                .rpcError(result: "err", context: "ctx"),
                "Transmission RPC ctx завершился с ошибкой: err"
            ),
            (
                .missingArguments(context: "ctx"),
                "Ответ Transmission ctx не содержит arguments секции"
            ),
            (
                .missingField(field: "field", context: "ctx"),
                "В ответе Transmission ctx отсутствует поле \"field\""
            ),
            (
                .invalidType(field: "field", expected: "Int", context: "ctx"),
                "Неверный тип поля \"field\" в ctx (ожидался Int)"
            ),
            (
                .invalidValue(field: "field", description: "bad", context: "ctx"),
                "Недопустимое значение поля \"field\" в ctx: bad"
            ),
            (
                .unsupportedStatus(rawValue: 7),
                "Статус торрента с rawValue=7 не поддерживается"
            ),
            (
                .emptyCollection(context: "ctx"),
                "Ответ Transmission ctx не содержит данных"
            )
        ]

        for (error, expected) in cases {
            #expect(error.errorDescription == expected)
        }
    }

    @Test
    func storedServerConfigRecordCodableRoundTrip() throws {
        let record = StoredServerConfigRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Test",
            host: "localhost",
            port: 9091,
            path: "/transmission/rpc",
            isSecure: false,
            username: "user",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(StoredServerConfigRecord.self, from: data)
        #expect(decoded == record)
    }
}
