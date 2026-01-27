import Clocks
import Foundation
import Testing

@testable import Remission

@Suite("Server Connection Probe Tests")
struct ServerConnectionProbeTests {
    // Проверяет, что калькулятор экспоненциальной задержки удваивает интервал.
    @Test
    func backoffCalculatorDoublesDelay() {
        var calculator = ServerConnectionProbe.ExponentialBackoffCalculator(
            initialDelay: .seconds(1),
            multiplier: 2.0
        )

        let delays = calculator.collectDelays(count: 3)

        #expect(seconds(from: delays[0]) == 1)
        #expect(seconds(from: delays[1]) == 2)
        #expect(seconds(from: delays[2]) == 4)
    }

    // Проверяет минимальный предел задержки при нулевом initialDelay.
    @Test
    func backoffCalculatorUsesMinimumDelay() {
        var calculator = ServerConnectionProbe.ExponentialBackoffCalculator(
            initialDelay: .zero,
            multiplier: 2.0
        )

        let delay = calculator.nextDelay()

        #expect(seconds(from: delay) >= 0.001)
    }

    @Test("Backoff calculator handles zero count")
    func testBackoffCalculatorZeroCount() {
        var calculator = ServerConnectionProbe.ExponentialBackoffCalculator(
            initialDelay: .seconds(1))
        let delays = calculator.collectDelays(count: 0)
        #expect(delays.isEmpty)
    }

    // Проверяет локализацию сообщений об ошибках таймаута.
    @Test
    func timeoutMessageIsLocalized() {
        let error = ServerConnectionProbe.ProbeError.handshakeFailed("Request timed out")

        let message = error.displayMessage

        #expect(
            message
                == "Истекло время ожидания подключения. Проверьте сеть или сервер и попробуйте снова."
        )
    }

    // Проверяет локализацию сообщений об отмене.
    @Test
    func cancelledMessageIsLocalized() {
        let error = ServerConnectionProbe.ProbeError.handshakeFailed("Cancelled by user")
        #expect(error.displayMessage == "Проверка подключения отменена. Повторите попытку.")

        let errorVariant = ServerConnectionProbe.ProbeError.handshakeFailed(
            "The operation was canceled")
        #expect(errorVariant.displayMessage == "Проверка подключения отменена. Повторите попытку.")
    }

    // Проверяет, что неизвестное сообщение не изменяется.
    @Test
    func unknownMessageIsPassedThrough() {
        let error = ServerConnectionProbe.ProbeError.handshakeFailed("Unknown error")

        let message = error.displayMessage

        #expect(message == "Unknown error")
    }

    // Проверяет предсказуемый мок для UI-тестов.
    @Test
    func uiTestMockReturnsCompatibleHandshake() async throws {
        let probe = ServerConnectionProbe.uiTestOnboardingMock()
        let server = ServerConfig.sample

        let result = try await probe.run(
            .init(server: server, password: nil),
            nil
        )

        #expect(result.handshake.isCompatible)
        #expect(result.handshake.sessionID?.hasPrefix("uitest-session-") == true)
    }

    // Note: Live probe tests with MockURLProtocol and TestClock are temporarily removed
    // as they cause xcodebuild to hang in CLI environment due to Task/Clock race conditions.
    // Core retry logic is covered in TransmissionClientRetryTests.

    private func seconds(from duration: Duration) -> Double {
        let components = duration.components
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return Double(components.seconds) + attoseconds
    }
}
