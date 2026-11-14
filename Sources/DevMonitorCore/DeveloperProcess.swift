import Foundation

/// A process plus the developer context DevMonitor adds on top of `ps`.
public struct DeveloperProcess: Equatable, Hashable, Sendable, Identifiable {
    public var process: ProcessRecord
    public var ports: [PortBinding]
    public var workingDirectory: String?
    public var project: ProjectContext?
    public var parents: ParentChain
    public var runtime: DevRuntime
    public var isSystem: Bool

    public var id: Int32 { process.pid }

    public var listeningPorts: [PortBinding] {
        ports.filter { $0.state == .listen }
    }

    public var listeningPortNumbers: [Int] {
        Array(Set(listeningPorts.map(\.localPort))).sorted()
    }

    public init(
        process: ProcessRecord,
        ports: [PortBinding],
        workingDirectory: String?,
        project: ProjectContext?,
        parents: ParentChain,
        runtime: DevRuntime,
        isSystem: Bool
    ) {
        self.process = process
        self.ports = ports
        self.workingDirectory = workingDirectory
        self.project = project
        self.parents = parents
        self.runtime = runtime
        self.isSystem = isSystem
    }
}
