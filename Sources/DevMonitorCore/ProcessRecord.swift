import Foundation

/// One row from `ps`. Memory is the resident set size in bytes.
/// `cpuPercent` is the `ps` `%cpu` column and can exceed 100 on a multi-core Mac.
/// `startTime` is derived as `now - elapsedSeconds` at parse time, because BSD `ps`
/// prints elapsed time more reliably than a locale-dependent start date.
public struct ProcessRecord: Equatable, Hashable, Sendable, Identifiable {
    public var pid: Int32
    public var ppid: Int32
    public var user: String
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public var elapsedSeconds: TimeInterval
    public var startTime: Date
    public var command: String
    public var name: String

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        ppid: Int32,
        user: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        elapsedSeconds: TimeInterval,
        startTime: Date,
        command: String,
        name: String
    ) {
        self.pid = pid
        self.ppid = ppid
        self.user = user
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.elapsedSeconds = elapsedSeconds
        self.startTime = startTime
        self.command = command
        self.name = name
    }
}

public enum ProcessName {
    /// Basename of argv[0], without a login-shell dash or a trailing colon
    /// (`postgres: checkpointer` → `postgres`, `-zsh` → `zsh`).
    public static func derive(from command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return trimmed
        }
        var token = String(first)
        if token.hasPrefix("("), token.hasSuffix(")"), token.count > 2 {
            token = String(token.dropFirst().dropLast())
        }
        var name = (token as NSString).lastPathComponent
        if name.hasPrefix("-"), name.count > 1 {
            name.removeFirst()
        }
        if name.hasSuffix(":"), name.count > 1 {
            name.removeLast()
        }
        return name
    }
}
