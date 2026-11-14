import Foundation

public enum EtimeParser {
    /// BSD `ps` etime: `mm:ss`, `hh:mm:ss`, or `dd-hh:mm:ss`.
    public static func seconds(from etime: String) -> TimeInterval? {
        let trimmed = etime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let dayParts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let days: Int
        let clock: String
        if dayParts.count == 2 {
            guard let parsedDays = Int(dayParts[0]), parsedDays >= 0, !dayParts[1].isEmpty else { return nil }
            days = parsedDays
            clock = dayParts[1]
        } else {
            days = 0
            clock = dayParts[0]
        }

        let pieces = clock.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count == 2 || pieces.count == 3 else { return nil }
        let numbers = pieces.compactMap(Int.init)
        guard numbers.count == pieces.count else { return nil }

        let hours: Int
        let minutes: Int
        let secs: Int
        if numbers.count == 2 {
            hours = 0
            minutes = numbers[0]
            secs = numbers[1]
        } else {
            hours = numbers[0]
            minutes = numbers[1]
            secs = numbers[2]
        }
        guard hours >= 0, (0..<60).contains(minutes), (0..<60).contains(secs) else { return nil }
        return TimeInterval(days * 86_400 + hours * 3_600 + minutes * 60 + secs)
    }
}

public enum UptimeFormat {
    public static func string(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(String(format: "%02d", secs))s" }
        return "\(secs)s"
    }
}

public enum ByteFormat {
    /// 1024-based, one decimal under 100, otherwise a whole number.
    public static func string(bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let units = ["KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unit = "B"
        for name in units {
            value /= 1024
            unit = name
            if value < 1024 || name == units.last { break }
        }
        if value >= 100 || abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f %@", value, unit)
        }
        return String(format: "%.1f %@", value, unit)
    }
}

public enum StartedFormat {
    /// Same calendar day: `HH:mm:ss`. Otherwise `yyyy-MM-dd HH:mm`.
    /// Pass an explicit calendar in tests so the result does not depend on the host timezone.
    public static func string(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: now) ? "HH:mm:ss" : "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
