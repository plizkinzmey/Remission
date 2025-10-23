import Foundation
import SwiftUI

enum TorrentDetailFormatters {
    static func statusText(for status: Int) -> String {
        switch status {
        case 0: return "Остановлен"
        case 1: return "Проверка очереди"
        case 2: return "Проверка"
        case 3: return "Очередь загрузки"
        case 4: return "Загрузка"
        case 5: return "Очередь раздачи"
        case 6: return "Раздача"
        default: return "Неизвестно"
        }
    }

    static func progress(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func bytes(_ bytes: Int) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func speed(_ bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else { return "0 КБ/с" }
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/с"
    }

    static func date(from timestamp: Int) -> String {
        let date: Date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func eta(_ seconds: Int) -> String {
        if seconds < 0 { return "—" }
        let hours: Int = seconds / 3600
        let minutes: Int = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else {
            return "\(minutes) мин"
        }
    }

    static func priorityText(_ priority: Int) -> String {
        switch priority {
        case 0: return "Низкий"
        case 2: return "Высокий"
        default: return "Нормальный"
        }
    }

    static func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 0: return .gray
        case 2: return .red
        default: return .blue
        }
    }
}
