import Foundation

/// Стратегия расчета задержек при повторных попытках (экспоненциальный рост).
enum BackoffStrategy {
    private static let defaultDelays: [Duration] = [
        .seconds(1),
        .seconds(2),
        .seconds(4),
        .seconds(8),
        .seconds(16),
        .seconds(30)
    ]

    /// Возвращает задержку для указанного количества неудачных попыток.
    /// - Parameter failures: Количество ошибок подряд.
    /// - Returns: Длительность ожидания.
    static func delay(for failures: Int) -> Duration {
        guard failures > 0 else { return .seconds(1) }
        let index = min(failures - 1, defaultDelays.count - 1)
        return defaultDelays[index]
    }
}
