import Foundation

public struct ProcessTreeNode: Equatable, Sendable, Identifiable {
    public var process: DeveloperProcess
    public var children: [ProcessTreeNode]

    public var id: Int32 { process.id }

    public init(process: DeveloperProcess, children: [ProcessTreeNode]) {
        self.process = process
        self.children = children
    }
}

public struct ProcessTreeBuilder: Sendable {
    public init() {}

    /// Roots are processes whose parent is not in `processes`. Children are
    /// ordered by CPU, highest first. Cycles are cut.
    public func roots(from processes: [DeveloperProcess]) -> [ProcessTreeNode] {
        let byPID = Dictionary(processes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var childrenOf: [Int32: [DeveloperProcess]] = [:]
        var roots: [DeveloperProcess] = []
        for process in processes {
            let parent = process.process.ppid
            if parent != process.id, byPID[parent] != nil {
                childrenOf[parent, default: []].append(process)
            } else {
                roots.append(process)
            }
        }
        var visited = Set<Int32>()
        func build(_ process: DeveloperProcess, trail: Set<Int32>) -> ProcessTreeNode {
            visited.insert(process.id)
            var nextTrail = trail
            nextTrail.insert(process.id)
            let kids = (childrenOf[process.id] ?? [])
                .filter { !nextTrail.contains($0.id) }
                .sorted { $0.process.cpuPercent > $1.process.cpuPercent }
            return ProcessTreeNode(
                process: process,
                children: kids.map { build($0, trail: nextTrail) }
            )
        }
        var forest = roots
            .sorted { $0.process.cpuPercent > $1.process.cpuPercent }
            .map { build($0, trail: []) }
        let stranded = processes.sorted { lhs, rhs in
            if lhs.process.cpuPercent == rhs.process.cpuPercent { return lhs.id < rhs.id }
            return lhs.process.cpuPercent > rhs.process.cpuPercent
        }
        for process in stranded where !visited.contains(process.id) {
            forest.append(build(process, trail: []))
        }
        return forest
    }
}
