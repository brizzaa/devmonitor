import Foundation
@testable import DevMonitorCore

enum Fixtures {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    static func process(
        pid: Int32,
        ppid: Int32 = 1,
        user: String = "luca",
        cpu: Double = 0,
        rssKB: UInt64 = 128,
        elapsed: TimeInterval = 10,
        command: String,
        name: String? = nil
    ) -> ProcessRecord {
        ProcessRecord(
            pid: pid,
            ppid: ppid,
            user: user,
            cpuPercent: cpu,
            memoryBytes: rssKB * 1024,
            elapsedSeconds: elapsed,
            startTime: now.addingTimeInterval(-elapsed),
            command: command,
            name: name ?? ProcessName.derive(from: command)
        )
    }

    static func developed(
        _ process: ProcessRecord,
        ports: [PortBinding] = [],
        workingDirectory: String? = nil,
        project: ProjectContext? = nil,
        parents: ParentChain = .none,
        runtime: DevRuntime = .unknown,
        isSystem: Bool = false
    ) -> DeveloperProcess {
        DeveloperProcess(
            process: process,
            ports: ports,
            workingDirectory: workingDirectory,
            project: project,
            parents: parents,
            runtime: runtime,
            isSystem: isSystem
        )
    }

    static func port(
        pid: Int32,
        command: String = "node",
        transport: Transport = .tcp,
        localAddress: String = "*",
        localPort: Int,
        remoteAddress: String? = nil,
        remotePort: Int? = nil,
        state: SocketState = .listen
    ) -> PortBinding {
        PortBinding(
            id: "\(pid)-\(localPort)-\(state.rawValue)",
            pid: pid,
            command: command,
            user: "luca",
            transport: transport,
            localAddress: localAddress,
            localPort: localPort,
            remoteAddress: remoteAddress,
            remotePort: remotePort,
            state: state
        )
    }
}

struct InMemoryFileSystem: FileSystemProbe {
    var files: [String: String] = [:]
    var entries: Set<String> = []

    func entryExists(at path: String) -> Bool {
        entries.contains(path) || files[path] != nil
    }

    func read(at path: String) -> String? {
        files[path]
    }
}

final class ScriptedRunner: CommandRunning, @unchecked Sendable {
    var calls: [(executable: String, arguments: [String])] = []
    var handler: (String, [String]) -> CommandOutput

    init(handler: @escaping (String, [String]) -> CommandOutput) {
        self.handler = handler
    }

    func run(executable: String, arguments: [String]) throws -> CommandOutput {
        calls.append((executable, arguments))
        return handler(executable, arguments)
    }
}

final class SpySignaler: ProcessSignaler, @unchecked Sendable {
    var calls: [(KillSignal, Int32)] = []
    var error: KillError?

    func send(_ signal: KillSignal, to pid: Int32) throws {
        calls.append((signal, pid))
        if let error { throw error }
    }
}
