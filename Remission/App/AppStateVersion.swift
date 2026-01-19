import Foundation

/// Версия корневого состояния приложения.
enum AppStateVersion: Int, CaseIterable, Codable, Equatable, Sendable {
    /// Состояние создано до появления системы версионирования.
    case legacy = 0
    case v1 = 1

    static let latest: AppStateVersion = .v1
}
