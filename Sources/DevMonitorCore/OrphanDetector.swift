import Foundation

public struct OrphanDetector: Sendable {
    /// Runtimes that are usually started from a shell or IDE and look abandoned
    /// once that session is gone. Databases and Docker are left alone: they are
    /// often supervised by launchd on purpose.
    public static let sessionRuntimes: Set<DevRuntime> = [
        .node, .bun, .deno, .python, .ruby, .java, .go, .rust, .swift, .php, .beam, .dotnet,
    ]

    public init() {}

    public func orphans(in processes: [DeveloperProcess]) -> [DeveloperProcess] {
        processes.filter(isOrphan).sorted { $0.process.cpuPercent > $1.process.cpuPercent }
    }

    public func isOrphan(_ process: DeveloperProcess) -> Bool {
        guard Self.sessionRuntimes.contains(process.runtime), !process.isSystem else { return false }
        if process.parents.links.contains(where: { $0.kind.isShell || $0.kind.isEnvironment }) {
            return false
        }
        if process.process.ppid <= 1 { return true }
        if process.parents.ancestors.isEmpty { return true }
        return process.parents.ancestors.allSatisfy { $0.kind == .launchd || $0.kind == .unknown }
    }
}
