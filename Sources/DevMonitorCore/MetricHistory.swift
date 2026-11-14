import Foundation

/// A fixed-length series of samples. Oldest values fall off the front.
public struct MetricHistory: Equatable, Sendable {
    public let capacity: Int
    public private(set) var samples: [Double]

    public init(capacity: Int = 30) {
        self.capacity = max(1, capacity)
        self.samples = []
    }

    public mutating func append(_ value: Double) {
        samples.append(value)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }
}

/// Per-process CPU samples across refreshes. PIDs that disappear are dropped.
public struct ProcessMetricStore: Equatable, Sendable {
    public var capacity: Int
    public private(set) var cpuByPID: [Int32: MetricHistory]

    public init(capacity: Int = 24) {
        self.capacity = max(1, capacity)
        self.cpuByPID = [:]
    }

    public mutating func record(_ processes: [DeveloperProcess]) {
        var next: [Int32: MetricHistory] = [:]
        next.reserveCapacity(processes.count)
        for process in processes {
            var history = cpuByPID[process.id] ?? MetricHistory(capacity: capacity)
            history.append(process.process.cpuPercent)
            next[process.id] = history
        }
        cpuByPID = next
    }

    public func series(for pid: Int32) -> [Double] {
        cpuByPID[pid]?.samples ?? []
    }
}
