import Foundation

public struct CommandOutput: Equatable, Sendable {
    public var status: Int32
    public var stdout: String
    public var stderr: String

    public init(status: Int32, stdout: String, stderr: String) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct CommandLaunchError: Error, Equatable, Sendable, CustomStringConvertible {
    public var executable: String
    public var message: String

    public init(executable: String, message: String) {
        self.executable = executable
        self.message = message
    }

    public var description: String { "\(executable): \(message)" }
}

public protocol CommandRunning: Sendable {
    func run(executable: String, arguments: [String]) throws -> CommandOutput
}

public enum ProcessCommands {
    public static let psExecutable = "/bin/ps"
    /// Wide BSD `ps`. Header suppressed by the `=` suffixes. Command is the remainder of the line.
    public static let psArguments = ["-axww", "-o", "pid=,ppid=,user=,%cpu=,rss=,etime=,command="]

    public static let lsofExecutable = "/usr/sbin/lsof"
    public static let listenArguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
    public static let establishedArguments = ["-nP", "-iTCP", "-sTCP:ESTABLISHED"]
    public static let udpArguments = ["-nP", "-iUDP"]
    /// Machine-readable working directories. `n` lines are absolute paths.
    public static let cwdArguments = ["-nP", "-d", "cwd", "-Fn"]
}

public struct FoundationCommandRunner: CommandRunning, Sendable {
    public init() {}

    public func run(executable: String, arguments: [String]) throws -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CommandLaunchError(executable: executable, message: error.localizedDescription)
        }

        // Read both pipes concurrently. Filling one buffer while we block on the
        // other deadlocks the child once the pipe hits its capacity.
        let group = DispatchGroup()
        let outBox = PipeBuffer()
        let errBox = PipeBuffer()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outBox.store(stdout.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errBox.store(stderr.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        process.waitUntilExit()
        group.wait()

        return CommandOutput(
            status: process.terminationStatus,
            stdout: String(data: outBox.data, encoding: .utf8) ?? "",
            stderr: String(data: errBox.data, encoding: .utf8) ?? ""
        )
    }
}

/// Mutable buffer shared with the pipe-reading queues. The queues only write
/// before `DispatchGroup.wait` returns, so the subsequent read is synchronized.
private final class PipeBuffer: @unchecked Sendable {
    private(set) var data = Data()
    func store(_ data: Data) { self.data = data }
}
