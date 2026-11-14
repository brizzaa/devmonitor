import Foundation

public enum RestartCommand {
    /// A line a shell can run. The working directory is single-quoted; the
    /// command is appended as recorded by `ps`.
    public static func shellLine(command: String, workingDirectory: String?) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let directory = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !directory.isEmpty else {
            return trimmed
        }
        return "cd \(posixSingleQuoted(directory)) && \(trimmed)"
    }

    public static func posixSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum LocalHTTPURL {
    /// `*`, `0.0.0.0`, and `::` become loopback. Other addresses are kept.
    public static func url(address: String, port: Int) -> URL? {
        guard (1...65535).contains(port) else { return nil }
        let host = normalizedHost(address)
        guard !host.isEmpty else { return nil }
        let rendered = host.contains(":") ? "[\(host)]" : host
        return URL(string: "http://\(rendered):\(port)/")
    }

    static func normalizedHost(_ address: String) -> String {
        var trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        switch trimmed {
        case "*", "", "0.0.0.0":
            return "127.0.0.1"
        case "::":
            return "::1"
        default:
            return trimmed
        }
    }
}
