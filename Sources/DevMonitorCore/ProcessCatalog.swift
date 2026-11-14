import Foundation

public enum ProcessSortKey: String, Equatable, Hashable, Sendable, CaseIterable {
    case pid
    case name
    case cpu
    case memory
    case user
    case startTime
    case uptime
    case command
    case project
    case port
}

public enum ProjectFilter: Equatable, Hashable, Sendable {
    case all
    case named(String)
    case unassigned
}

public struct ProcessQuery: Equatable, Sendable {
    public var searchText: String
    public var hideSystem: Bool
    public var developerRuntimesOnly: Bool
    public var projectFilter: ProjectFilter
    public var port: Int?

    public init(
        searchText: String = "",
        hideSystem: Bool = false,
        developerRuntimesOnly: Bool = false,
        projectFilter: ProjectFilter = .all,
        port: Int? = nil
    ) {
        self.searchText = searchText
        self.hideSystem = hideSystem
        self.developerRuntimesOnly = developerRuntimesOnly
        self.projectFilter = projectFilter
        self.port = port
    }
}

public struct ProjectGroup: Equatable, Sendable, Identifiable {
    public var name: String
    public var isUnassigned: Bool
    public var processes: [DeveloperProcess]

    public var id: String { isUnassigned ? "\u{0}unassigned" : name }

    public init(name: String, isUnassigned: Bool, processes: [DeveloperProcess]) {
        self.name = name
        self.isUnassigned = isUnassigned
        self.processes = processes
    }
}

public struct ProcessCatalog: Sendable {
    public init() {}

    public func filtered(_ processes: [DeveloperProcess], query: ProcessQuery) -> [DeveloperProcess] {
        processes.filter { process in
            if query.hideSystem && process.isSystem { return false }
            if query.developerRuntimesOnly && !process.runtime.isDeveloperFacing { return false }
            if let port = query.port, !process.ports.contains(where: { $0.localPort == port }) {
                return false
            }
            switch query.projectFilter {
            case .all:
                break
            case .named(let name):
                if process.project?.projectName != name { return false }
            case .unassigned:
                if projectName(of: process) != nil { return false }
            }
            return matchesSearch(process, text: query.searchText)
        }
    }

    public func sorted(
        _ processes: [DeveloperProcess],
        key: ProcessSortKey,
        ascending: Bool
    ) -> [DeveloperProcess] {
        processes.sorted { lhs, rhs in
            if key == .port || key == .project {
                return compareOptionalLast(lhs, rhs, key: key, ascending: ascending)
            }
            let primary = compare(lhs, rhs, key: key)
            if primary == .orderedSame {
                return lhs.process.pid < rhs.process.pid
            }
            return ascending ? primary == .orderedAscending : primary == .orderedDescending
        }
    }

    /// Groups keep the incoming order. Named groups are alphabetical, case-insensitive.
    /// Processes with no project name go in a final "No project" group.
    public func groupedByProject(_ processes: [DeveloperProcess]) -> [ProjectGroup] {
        var buckets: [String: [DeveloperProcess]] = [:]
        var unassigned: [DeveloperProcess] = []
        var order: [String] = []
        for process in processes {
            if let name = projectName(of: process) {
                if buckets[name] == nil { order.append(name) }
                buckets[name, default: []].append(process)
            } else {
                unassigned.append(process)
            }
        }
        let names = order.sorted { $0.lowercased() < $1.lowercased() }
        var groups = names.map { name in
            ProjectGroup(name: name, isUnassigned: false, processes: buckets[name] ?? [])
        }
        if !unassigned.isEmpty {
            groups.append(ProjectGroup(name: "No project", isUnassigned: true, processes: unassigned))
        }
        return groups
    }

    private func projectName(of process: DeveloperProcess) -> String? {
        guard let name = process.project?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    private func matchesSearch(_ process: DeveloperProcess, text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return true }
        if process.process.name.lowercased().contains(query) { return true }
        if process.process.command.lowercased().contains(query) { return true }
        if process.process.user.lowercased().contains(query) { return true }
        if String(process.process.pid).contains(query) { return true }
        if process.project?.projectName?.lowercased().contains(query) == true { return true }
        if process.project?.gitRoot?.lowercased().contains(query) == true { return true }
        if process.workingDirectory?.lowercased().contains(query) == true { return true }
        if process.runtime != .unknown && process.runtime.label.lowercased().contains(query) { return true }
        if process.parents.summary.lowercased().contains(query) { return true }
        if process.ports.contains(where: {
            String($0.localPort).contains(query) || $0.localAddress.lowercased().contains(query)
        }) { return true }
        return false
    }

    private func compare(_ lhs: DeveloperProcess, _ rhs: DeveloperProcess, key: ProcessSortKey) -> ComparisonResult {
        switch key {
        case .pid:
            return cmp(lhs.process.pid, rhs.process.pid)
        case .name:
            return cmp(lhs.process.name.lowercased(), rhs.process.name.lowercased())
        case .cpu:
            return cmp(lhs.process.cpuPercent, rhs.process.cpuPercent)
        case .memory:
            return cmp(lhs.process.memoryBytes, rhs.process.memoryBytes)
        case .user:
            return cmp(lhs.process.user.lowercased(), rhs.process.user.lowercased())
        case .startTime:
            return cmp(lhs.process.startTime, rhs.process.startTime)
        case .uptime:
            return cmp(lhs.process.elapsedSeconds, rhs.process.elapsedSeconds)
        case .command:
            return cmp(lhs.process.command.lowercased(), rhs.process.command.lowercased())
        case .project, .port:
            return .orderedSame
        }
    }

    private func compareOptionalLast(
        _ lhs: DeveloperProcess,
        _ rhs: DeveloperProcess,
        key: ProcessSortKey,
        ascending: Bool
    ) -> Bool {
        switch key {
        case .port:
            return compareNilsLast(
                lhs.listeningPortNumbers.first,
                rhs.listeningPortNumbers.first,
                pidL: lhs.process.pid,
                pidR: rhs.process.pid,
                ascending: ascending
            )
        case .project:
            return compareNilsLast(
                projectName(of: lhs)?.lowercased(),
                projectName(of: rhs)?.lowercased(),
                pidL: lhs.process.pid,
                pidR: rhs.process.pid,
                ascending: ascending
            )
        default:
            return lhs.process.pid < rhs.process.pid
        }
    }

    private func compareNilsLast<T: Comparable>(
        _ lhs: T?,
        _ rhs: T?,
        pidL: Int32,
        pidR: Int32,
        ascending: Bool
    ) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            if left == right { return pidL < pidR }
            return ascending ? left < right : left > right
        case (nil, nil):
            return pidL < pidR
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func cmp<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}
