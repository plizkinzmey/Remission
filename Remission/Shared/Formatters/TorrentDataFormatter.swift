import Foundation

/// Унифицированный форматер для данных торрентов (байты, скорость, время).
enum TorrentDataFormatter {
    /// Форматирует количество байт (например, "1.2 ГБ").
    static func bytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = .useAll
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }

    /// Форматирует скорость (например, "500 КБ/с").
    static func speed(_ bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "0 Б/с"
        }
        return "\(bytes(Int64(bytesPerSecond)))/с"
    }

    /// Форматирует оставшееся время (ETA).
    static func eta(_ seconds: Int) -> String {
        guard seconds >= 0 else {
            return L10n.tr("torrentDetail.eta.placeholder")
        }
        guard seconds > 0 else {
            return "0с"
        }
        
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        
        if let formatted = formatter.string(from: TimeInterval(seconds)) {
            return formatted
        }
        return L10n.tr("torrentDetail.eta.placeholder")
    }

    /// Форматирует прогресс в процентах (например, "45.2%").
    static func progress(_ fraction: Double) -> String {
        let clamped = max(0, min(fraction, 1))
        return String(format: "%.1f%%", clamped * 100)
    }
}
