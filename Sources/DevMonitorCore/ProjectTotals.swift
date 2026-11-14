import Foundation

public struct ProjectResourceTotal: Equatable, Sendable, Identifiable {
    public var name: String
    public var isUnassigned: Bool
    public var processCount: Int
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public var listeningPortCount: Int

    public var id: String { isUnassigned ? "\u{0}unassigned" : name }

    public init(
        name: String,
        isUnassigned: Bool,
        processCount: Int,
        cpuPercent: Double,
        memoryBytes: UInt64,
        listeningPortCount: Int
    ) {
        self.name = name
        self.isUnassigned = isUnassigned
        self.processCount = processCount
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.listeningPortCount = listeningPortCount
    }
}

public struct DashboardStats: Equatable, Sendable {
    public var developerCPU: Double
    public var developerMemory: UInt64
    public var developerCount: Int
    public var listeningPortCount: Int

    public init(developerCPU: Double, developerMemory: UInt64, developerCount: Int, listeningPortCount: Int) {
        self.developerCPU = developerCPU
        self.developerMemory = developerMemory
        self.developerCount = developerCount
        self.listeningPortCount = listeningPortCount
    }

    /// CPU and memory are summed across recognised dev runtimes.
    /// Listening ports are the unique local ports of every non-system process.
    public static func make(from processes: [DeveloperProcess]) -> DashboardStats {
        var cpu = 0.0
        var memory: UInt64 = 0
        var developers = 0
        var ports = Set<Int>()
        for process in processes {
            if process.runtime.isDeveloperFacing {
                developers += 1
                cpu += process.process.cpuPercent
                memory = saturatingAdd(memory, process.process.memoryBytes)
            }
            if !process.isSystem {
                for port in process.listeningPortNumbers {
                    ports.insert(port)
                }
            }
        }
        return DashboardStats(
            developerCPU: cpu,
            developerMemory: memory,
            developerCount: developers,
            listeningPortCount: ports.count
        )
    }
}

public enum ProjectTotals {
    /// One row per project name, highest CPU first. Processes with no project
    /// share a trailing "No project" row when any exist.
    public static func summarize(_ processes: [DeveloperProcess]) -> [ProjectResourceTotal] {
        struct Bucket {
            var count = 0
            var cpu = 0.0
            var memory: UInt64 = 0
            var ports = Set<Int>()
        }
        var named: [String: Bucket] = [:]
        var unassigned = Bucket()
        var sawUnassigned = false
        for process in processes {
            let ports = Set(process.listeningPortNumbers)
            if let name = projectName(of: process) {
                var bucket = named[name] ?? Bucket()
                bucket.count += 1
                bucket.cpu += process.process.cpuPercent
                bucket.memory = saturatingAdd(bucket.memory, process.process.memoryBytes)
                bucket.ports.formUnion(ports)
                named[name] = bucket
            } else {
                sawUnassigned = true
                unassigned.count += 1
                unassigned.cpu += process.process.cpuPercent
                unassigned.memory = saturatingAdd(unassigned.memory, process.process.memoryBytes)
                unassigned.ports.formUnion(ports)
            }
        }
        var rows = named.map { name, bucket in
            ProjectResourceTotal(
                name: name,
                isUnassigned: false,
                processCount: bucket.count,
                cpuPercent: bucket.cpu,
                memoryBytes: bucket.memory,
                listeningPortCount: bucket.ports.count
            )
        }
        rows.sort { lhs, rhs in
            if lhs.cpuPercent == rhs.cpuPercent {
                return lhs.name.lowercased() < rhs.name.lowercased()
            }
            return lhs.cpuPercent > rhs.cpuPercent
        }
        if sawUnassigned {
            rows.append(
                ProjectResourceTotal(
                    name: "No project",
                    isUnassigned: true,
                    processCount: unassigned.count,
                    cpuPercent: unassigned.cpu,
                    memoryBytes: unassigned.memory,
                    listeningPortCount: unassigned.ports.count
                )
            )
        }
        return rows
    }

    private static func projectName(of process: DeveloperProcess) -> String? {
        guard let name = process.project?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }
}

func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    lhs > UInt64.max - rhs ? UInt64.max : lhs + rhs
}
