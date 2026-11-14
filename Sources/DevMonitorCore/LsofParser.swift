import Foundation

/// Parses the human-readable table from `lsof -nP -iTCP -sTCP:LISTEN`
/// (and the same shape for UDP and established TCP).
///
/// Expected columns: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME.
/// NODE is `TCP` or `UDP`. NAME looks like `*:3000 (LISTEN)` or
/// `10.0.0.5:51234->93.184.216.34:443 (ESTABLISHED)`.
public struct LsofParser {
    public init() {}

    public func parse(_ output: String) -> [PortBinding] {
        var bindings: [PortBinding] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            guard let binding = parseLine(text, index: bindings.count) else { continue }
            bindings.append(binding)
        }
        return bindings
    }

    private func parseLine(_ line: String, index: Int) -> PortBinding? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var parts: [Substring] = []
        var rest = trimmed[...]
        // COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE, then the NAME remainder.
        for _ in 0..<8 {
            rest = rest.drop(while: { $0 == " " || $0 == "\t" })
            if rest.isEmpty { return nil }
            if let split = rest.firstIndex(where: { $0 == " " || $0 == "\t" }) {
                parts.append(rest[..<split])
                rest = rest[split...]
            } else {
                parts.append(rest)
                rest = Substring()
            }
        }
        guard parts.count == 8 else { return nil }
        let node = String(parts[7]).uppercased()
        guard let transport = Transport(rawValue: node.lowercased()) else { return nil }
        guard let pid = Int32(parts[1]) else { return nil }
        rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        let name = String(rest)
        guard !name.isEmpty, let endpoint = Self.parseName(name, transport: transport) else { return nil }

        let id = "\(pid):\(transport.rawValue):\(endpoint.local.0):\(endpoint.local.1):\(endpoint.state.rawValue):\(index)"
        return PortBinding(
            id: id,
            pid: pid,
            command: String(parts[0]),
            user: String(parts[2]),
            transport: transport,
            localAddress: endpoint.local.0,
            localPort: endpoint.local.1,
            remoteAddress: endpoint.remote?.0,
            remotePort: endpoint.remote?.1,
            state: endpoint.state
        )
    }

    static func parseName(
        _ name: String,
        transport: Transport
    ) -> (local: (String, Int), remote: (String, Int)?, state: SocketState)? {
        var rest = name.trimmingCharacters(in: .whitespaces)
        var state: SocketState = transport == .udp ? .listen : .other
        if rest.hasSuffix(")"), let open = rest.lastIndex(of: "(") {
            let insideStart = rest.index(after: open)
            let insideEnd = rest.index(before: rest.endIndex)
            let token = rest[insideStart..<insideEnd].trimmingCharacters(in: .whitespaces).uppercased()
            switch token {
            case "LISTEN": state = .listen
            case "ESTABLISHED": state = .established
            default: state = .other
            }
            rest = rest[..<open].trimmingCharacters(in: .whitespaces)
        }
        let sides = rest.components(separatedBy: "->")
        guard let local = parseEndpoint(sides[0]) else { return nil }
        let remote: (String, Int)? = sides.count > 1 ? parseEndpoint(sides[1]) : nil
        return (local, remote, state)
    }

    static func parseEndpoint(_ raw: String) -> (String, Int)? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("[") {
            guard let close = value.firstIndex(of: "]") else { return nil }
            let host = String(value[value.index(after: value.startIndex)..<close])
            let after = value[value.index(after: close)...]
            guard after.hasPrefix(":") else { return nil }
            guard let port = Int(after.dropFirst()), (0...65535).contains(port) else { return nil }
            return (host, port)
        }
        guard let colon = value.lastIndex(of: ":") else { return nil }
        let host = String(value[..<colon])
        let portText = String(value[value.index(after: colon)...])
        guard !host.isEmpty, let port = Int(portText), (0...65535).contains(port) else { return nil }
        return (host, port)
    }
}
