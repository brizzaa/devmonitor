import Foundation

public enum KillSignal: Int32, Equatable, Hashable, Sendable {
    case term = 15
    case kill = 9

    public var name: String {
        switch self {
        case .term: return "SIGTERM"
        case .kill: return "SIGKILL"
        }
    }
}

public enum KillError: Error, Equatable, Sendable {
    case invalidPid
    case permissionDenied(pid: Int32)
    case noSuchProcess(pid: Int32)
    case underlying(pid: Int32, message: String)

    public var userMessage: String {
        switch self {
        case .invalidPid:
            return "That PID is not valid."
        case .permissionDenied(let pid):
            return "Permission denied for PID \(pid). DevMonitor can only signal processes your user owns. macOS refuses other users' processes and protected system processes unless you run the app with administrator privileges."
        case .noSuchProcess(let pid):
            return "PID \(pid) is no longer running."
        case .underlying(let pid, let message):
            return "Could not signal PID \(pid). \(message)"
        }
    }
}

public enum KillResult: Equatable, Sendable {
    case sent(pid: Int32, signal: KillSignal)
    case failed(KillError)
}

public protocol ProcessSignaler: Sendable {
    func send(_ signal: KillSignal, to pid: Int32) throws
}

public struct KillService: Sendable {
    private let signaler: any ProcessSignaler

    public init(signaler: any ProcessSignaler) {
        self.signaler = signaler
    }

    public func kill(pid: Int32, signal: KillSignal) -> KillResult {
        // pid 0 and negative pids are signal-group destinations. Never pass them to kill(2).
        guard pid > 0 else { return .failed(.invalidPid) }
        do {
            try signaler.send(signal, to: pid)
            return .sent(pid: pid, signal: signal)
        } catch let error as KillError {
            return .failed(error)
        } catch {
            return .failed(.underlying(pid: pid, message: String(describing: error)))
        }
    }

    /// Signals each distinct PID that has a socket with this local port.
    /// The remote port is ignored, so a browser talking to :3000 is not killed.
    public func killProcesses(
        boundToLocalPort port: Int,
        bindings: [PortBinding],
        signal: KillSignal
    ) -> [KillResult] {
        var seen = Set<Int32>()
        var pids: [Int32] = []
        for binding in bindings where binding.localPort == port {
            if seen.insert(binding.pid).inserted {
                pids.append(binding.pid)
            }
        }
        return pids.map { kill(pid: $0, signal: signal) }
    }
}
