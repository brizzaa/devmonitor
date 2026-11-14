import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public struct SystemProcessSignaler: ProcessSignaler, Sendable {
    public init() {}

    public func send(_ signal: KillSignal, to pid: Int32) throws {
        guard pid > 0 else { throw KillError.invalidPid }
        errno = 0
        let result = kill(pid, signal.rawValue)
        if result != 0 {
            let error = errno
            if error == EPERM { throw KillError.permissionDenied(pid: pid) }
            if error == ESRCH { throw KillError.noSuchProcess(pid: pid) }
            let message = error == 0 ? "kill returned \(result)" : String(cString: strerror(error))
            throw KillError.underlying(pid: pid, message: message)
        }
    }
}
