import Foundation

/// Parses `lsof -nP -d cwd -Fn`.
///
/// Field mode emits one field per line, prefixed by an identifier:
/// `p` pid, `f` file descriptor, `n` path. Only `cwd` entries are kept.
public struct CwdParser {
    public init() {}

    public func parse(_ output: String) -> [Int32: String] {
        var result: [Int32: String] = [:]
        var currentPID: Int32?
        var currentFD: String?
        for line in output.split(whereSeparator: \.isNewline) {
            guard let identifier = line.first else { continue }
            let value = String(line.dropFirst())
            switch identifier {
            case "p":
                currentPID = Int32(value)
                currentFD = nil
            case "f":
                currentFD = value
            case "n":
                guard let pid = currentPID, !value.isEmpty else { continue }
                if currentFD == nil || currentFD == "cwd" {
                    result[pid] = value
                }
            default:
                break
            }
        }
        return result
    }
}
