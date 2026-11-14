import Foundation

public struct SnapshotAssembler: Sendable {
    private let runtimeClassifier: RuntimeClassifier
    private let systemHeuristic: SystemProcessHeuristic
    private let parents: ParentChainResolver

    public init(
        runtimeClassifier: RuntimeClassifier = RuntimeClassifier(),
        systemHeuristic: SystemProcessHeuristic = SystemProcessHeuristic(),
        parents: ParentChainResolver = ParentChainResolver()
    ) {
        self.runtimeClassifier = runtimeClassifier
        self.systemHeuristic = systemHeuristic
        self.parents = parents
    }

    public func assemble(
        processes: [ProcessRecord],
        ports: [PortBinding],
        workingDirectories: [Int32: String],
        projects: [String: ProjectContext]
    ) -> [DeveloperProcess] {
        let portsByPID = Dictionary(grouping: deduplicated(ports), by: \.pid)
        return processes.map { process in
            let cwd = workingDirectories[process.pid]
            let project = cwd.flatMap { projects[$0] }
            let runtime = runtimeClassifier.classify(name: process.name, command: process.command)
            let sortedPorts = (portsByPID[process.pid] ?? []).sorted {
                if $0.localPort == $1.localPort { return $0.state.rawValue < $1.state.rawValue }
                return $0.localPort < $1.localPort
            }
            return DeveloperProcess(
                process: process,
                ports: sortedPorts,
                workingDirectory: cwd,
                project: project,
                parents: parents.resolve(pid: process.pid, processes: processes),
                runtime: runtime,
                isSystem: systemHeuristic.isSystem(process, runtime: runtime)
            )
        }
    }

    private func deduplicated(_ ports: [PortBinding]) -> [PortBinding] {
        var seen = Set<String>()
        return ports.filter { binding in
            let key = [
                String(binding.pid),
                binding.transport.rawValue,
                binding.localAddress,
                String(binding.localPort),
                binding.remoteAddress ?? "",
                String(binding.remotePort ?? -1),
                binding.state.rawValue,
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
