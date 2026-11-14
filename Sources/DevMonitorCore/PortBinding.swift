import Foundation

public enum Transport: String, Equatable, Hashable, Sendable {
    case tcp
    case udp
}

public enum SocketState: String, Equatable, Hashable, Sendable {
    case listen
    case established
    case other
}

/// One socket from `lsof -nP -i`. `localPort` is the port on this machine.
/// A client connection to a remote :3000 has an ephemeral `localPort` and is not
/// treated as "the process listening on 3000".
public struct PortBinding: Equatable, Hashable, Sendable, Identifiable {
    public var id: String
    public var pid: Int32
    public var command: String
    public var user: String
    public var transport: Transport
    public var localAddress: String
    public var localPort: Int
    public var remoteAddress: String?
    public var remotePort: Int?
    public var state: SocketState

    public init(
        id: String,
        pid: Int32,
        command: String,
        user: String,
        transport: Transport,
        localAddress: String,
        localPort: Int,
        remoteAddress: String? = nil,
        remotePort: Int? = nil,
        state: SocketState
    ) {
        self.id = id
        self.pid = pid
        self.command = command
        self.user = user
        self.transport = transport
        self.localAddress = localAddress
        self.localPort = localPort
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.state = state
    }
}

public struct PortLookup {
    public init() {}

    /// Bindings whose local port is `port`. Remote port is ignored.
    public func bindings(on port: Int, in bindings: [PortBinding], listeningOnly: Bool = false) -> [PortBinding] {
        bindings.filter { binding in
            guard binding.localPort == port else { return false }
            if listeningOnly && binding.state != .listen { return false }
            return true
        }
    }
}
